########################################
# Amazon Location Service -- address autocomplete for in-person forms.
#
# HERE rather than Esri as the data provider, deliberately: Esri's terms do
# not permit persisting geocoding results, and a chosen venue address is
# stored on the poll item. HERE permits it under intended_use = "Storage".
########################################

resource "aws_location_place_index" "places" {
  index_name  = "${var.app_name}-places"
  data_source = "Here"
  description = "Address autocomplete for in-person Xomforms events"

  data_source_configuration {
    intended_use = "Storage"
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-places" }))
}

output "place_index_name" {
  description = "Amazon Location place index backing address autocomplete"
  value       = aws_location_place_index.places.index_name
}
