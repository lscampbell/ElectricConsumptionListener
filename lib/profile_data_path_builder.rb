class ProfileDataPathBuilder
  def self.build(customer, supply_point_reference, date)
    "/#{customer}/supply-points/#{supply_point_reference}/#{date.strftime('%F')}"
  end
end