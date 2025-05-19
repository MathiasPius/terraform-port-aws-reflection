
resource "port_blueprint" "rds" {
  title      = "RDS"
  icon       = "Database"
  identifier = "rds"
  properties = {
    object_props = {
      json = {
        type     = "object"
        required = true
      }
    }
  }
  calculation_properties = {
    DbInstanceIdentifier = {
      title       = "Id"
      type        = "string"
      calculation = ".properties.json.DbInstanceIdentifier"
    }
    DbInstanceClass = {
      title       = "Class"
      type        = "string"
      calculation = ".properties.json.DbInstanceClass"
    }
    Engine = {
      title       = "Engine"
      type        = "string"
      calculation = ".properties.json.Engine"
    }
    Endpoint = {
      title       = "Endpoint"
      type        = "string"
      calculation = ".properties.json.Endpoint.Address"
    }
  }
}

module "webhook" {
  source = ".."

  providers = {
    aws       = aws
    port-labs = port-labs
  }

  resources = {
    (port_blueprint.rds.identifier) = {
      identifier = "DbInstanceArn"

      api = {
        type_name       = "DbInstance"
        action          = "rds:DescribeDBInstances"
        delete_on_error = ["Rds.DbInstanceNotFoundException"]
      }

      mapping = {
        title = "DbInstanceIdentifier"
        properties = {
          "json" = ".item"
        }
      }

      events = {
        pattern = {
          source = [
            "aws.rds"
          ]
          "detail-type" : [
            "RDS DB Instance Event"
          ]
          # "detail" : {
          #   "EventCategories" = ["creation", "deletion", "restoration", "configuration change", "availability"]
          # }
        }
      }
    }
  }

  webhook = {
    identifier = "port_aws_rds_reflection"
    name       = "RDS Mapper"
  }

  step_function = {
    name = "port_aws_rds_reflection"
  }

  events = {}
}

# Make changes to this to verify the event subscription works
resource "aws_db_instance" "default" {
  provider            = aws.source
  allocated_storage   = 5
  identifier          = "mydb"
  db_name             = "mydb"
  engine              = "postgres"
  engine_version      = "16.8"
  instance_class      = "db.t4g.micro"
  username            = "foo"
  password            = "barbarbar"
  skip_final_snapshot = true
  apply_immediately   = true
}
