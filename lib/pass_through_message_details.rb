class PassThroughMessageDetails
  def self.to_hash(request)
    {
        distribution_area: request['distribution_area'],
        llf_class: request['llf_class'],
        customer: request['customer'],
        supply_point_reference: request['supply_point_reference'],
        date: request['date'],
        bands: request['bands'],
        supply_capacity: request['supply_capacity']
    }
  end
end