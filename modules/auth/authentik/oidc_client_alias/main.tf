locals {
  labels = {
    "app.kubernetes.io/name" = var.name
  }

  config_path   = "/usr/local/openresty/nginx/conf/nginx.conf"
  upstream_fqdn = "${var.upstream_host}.${var.namespace}.svc.cluster.local"
  port          = 8080

  # Rendered into the Lua table below; a bare `$` is not interpolation, so the rest of the
  # config can keep nginx's `$host`-style variables verbatim.
  aliases_lua = join("\n", [
    for from, to in var.aliases : "              [\"${from}\"] = \"${to}\","
  ])

  nginx_conf = <<-EOT
    worker_processes 1;
    error_log /dev/stderr warn;
    pid /tmp/nginx.pid;

    events {
      worker_connections 256;
    }

    http {
      access_log off;

      client_body_temp_path /tmp/client_body;
      proxy_temp_path       /tmp/proxy;
      fastcgi_temp_path     /tmp/fastcgi;
      uwsgi_temp_path       /tmp/uwsgi;
      scgi_temp_path        /tmp/scgi;

      client_body_buffer_size 256k;
      client_max_body_size    1m;

      upstream authentik {
        server ${local.upstream_fqdn}:${var.upstream_port};
        keepalive 8;
      }

      server {
        listen ${local.port};
        server_name _;

        location = /healthz {
          add_header Content-Type text/plain;
          return 200 "ok\n";
        }

        location / {
          rewrite_by_lua_block {
            local aliases = {
    ${local.aliases_lua}
            }

            local function canonical(client_id)
              if client_id == nil then
                return nil
              end
              return aliases[client_id]
            end

            if ngx.var.uri == "/application/o/token/" then
              -- The apps authenticate either with credentials in the body or with a Basic
              -- header; the secret is ignored by the provider, so only the id has to move.
              ngx.req.read_body()
              local args = ngx.req.get_post_args()
              local cid = args["client_id"]

              if cid == nil then
                local auth = ngx.req.get_headers()["authorization"]
                if type(auth) == "string" and auth:sub(1, 6) == "Basic " then
                  local decoded = ngx.decode_base64(auth:sub(7))
                  if decoded then
                    cid = decoded:match("^([^:]*):")
                  end
                end
              end

              local to = canonical(cid)
              if to ~= nil then
                args["client_id"] = to
                local body = ngx.encode_args(args)
                ngx.req.set_body_data(body)
                ngx.req.set_header("Content-Length", #body)
                ngx.req.clear_header("Authorization")
              end
            else
              local to = canonical(ngx.var.arg_client_id)
              if to ~= nil then
                local args = ngx.req.get_uri_args()
                args["client_id"] = to
                ngx.req.set_uri_args(args)
              end
            end
          }

          proxy_pass http://authentik;
          proxy_http_version 1.1;

          # Only Host and Connection are touched; the gateway's X-Forwarded-* pass through
          # verbatim. authentik derives a token's issuer from the scheme it sees, so rewriting
          # X-Forwarded-Proto to this hop's http would mint every token with an http:// issuer
          # that oCIS's strict verification then rejects.
          proxy_set_header Connection "";
          proxy_set_header Host $host;
        }
      }
    }
  EOT
}

resource "kubernetes_config_map_v1" "config" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "nginx.conf" = local.nginx_conf
  }
}

resource "kubernetes_deployment_v1" "proxy" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 2

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels

        annotations = {
          "checksum/nginx-conf" = sha256(local.nginx_conf)
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 101
          run_as_group    = 101

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name    = "proxy"
          image   = "${var.image}:${var.image_tag}"
          command = ["/usr/local/openresty/bin/openresty"]

          args = [
            "-p", "/tmp",
            "-c", local.config_path,
            "-g", "daemon off;",
          ]

          port {
            name           = "http"
            container_port = local.port
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/usr/local/openresty/nginx/conf"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          # nginx opens a default error log under the prefix before it reads the config.
          volume_mount {
            name       = "logs"
            mount_path = "/tmp/logs"
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map_v1.config.metadata[0].name
          }
        }

        volume {
          name = "tmp"

          empty_dir {}
        }

        volume {
          name = "logs"

          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "proxy" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}
