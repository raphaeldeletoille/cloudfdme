variable "all_rg" {
  type = map 
  default = {
    rg1 = {
        name = "rg"
        location = "West Europe"
        tags = { "Number" = "1" }
    },
    rg2 = {
        name = "rg2"
        location = "West US"
        tags = { "Number" = "2" }
    },
    rg3 = {
        name = "rg3"
        location = "Japan East"
        tags = { "Number" = "3" }
    }
  }
}

variable "my_name" {
  type = string 
  default = "raph"
}

variable "location" {
    type = string 
  default = "West Europe"
}