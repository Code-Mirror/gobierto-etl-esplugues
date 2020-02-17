#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
Bundler.require

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Organization ID
#  - 1: Absolute path to a file containing a CSV of providers
#  - 2: Output json path
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/import-providers/run.rb 8077 input.json output.json
#

DNI_REGEX = /\A\d{8}[A-Z]/i
NIE_REGEX = /\A[A-Z]\d{7}[A-Z]/i

def freelance?(row)
  row["freelance"].downcase == "true" ||
  row["provider_id"].match?(DNI_REGEX) ||
  row["provider_id"].match?(NIE_REGEX)
end

def parse_invoice_row(row)
  formatted_date = Date.strptime(row["date"], "%d/%m/%Y").strftime("%Y-%m-%d")
  value = row["value"].tr(".", "").tr(",", ".").to_f

  {
    value: value,
    date: formatted_date,
    invoice_id: row["invoice_id"],
    provider_id: row["provider_id"],
    provider_name: row["provider_name"].try(:strip),
    subject: row["subject"],
    freelance: freelance?(row)
  }
end

if ARGV.length != 3
  raise "At least one argument is required"
end

organization_id = ARGV[0].to_s
data_file = ARGV[1]
output_file = ARGV[2]
output_data = []

place = INE::Places::Place.find(organization_id)
base_attributes = {
  location_id: place.id,
  province_id: place.province.id,
  autonomous_region_id: place.province.autonomous_region.id
}

puts "[START] transform-providers/run.rb data_file=#{data_file} output_file=#{output_file}"

nitems = 0

CSV.foreach(data_file, headers: true, col_sep: ",", quote_char: '"') do |row|
  begin
    attributes = base_attributes.merge(parse_invoice_row(row))
    nitems += 1
    output_data << attributes
  rescue ArgumentError => e
    puts e
    puts row
  end
end

File.write(output_file, output_data.to_json)

puts "[END] transform-providers/run.rb transformed #{nitems} items"
