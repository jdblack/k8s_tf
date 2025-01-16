 
variable namespace  { default = "kube-network" }
variable name       { default = "dyndns" }

variable image      { default = "dyndns"   }
variable registry   { type    = string     }

variable domain     { type    = string     }
variable port       { default = 8080       }
variable r53_zone   { type = string        }
variable AWS_ACCESS_KEY_ID  { type = string }
variable AWS_SECRET_ACCESS_KEY  { type = string }
variable AWS_REGION { type = string }




