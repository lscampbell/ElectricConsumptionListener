module ProfileConverter
  def convert_profile_data
    map { |dp| dp.merge(
        'start' => DateTime.parse(dp['start']),
        'end' => DateTime.parse(dp['end']),
        'kwh' => dp['kwh'].to_f
    ) }
  end

  def convert_dates
    map { |dp| dp.merge(
        'start' => DateTime.parse(dp['start']),
        'end' => DateTime.parse(dp['end'])
    ) }
  end
end

class Array
  include ProfileConverter
end