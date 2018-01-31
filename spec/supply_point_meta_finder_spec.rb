require 'json'

describe SupplyPointMetaFinder do
  context 'when profile.data.entry event is received' do
    let(:listener) { SupplyPointMetaFinder.new }
    let(:data) { [{'kwh' => 65}] }
    let(:message) do
      {
          mpan: mpan_top_row + '-1234-321-' + '120',
          date: DateTime.new(2016, 01, 01),
          data: data
      }
    end
    let(:mpan_top_row) { '001234-5432' }

    before :each do
      allow(ElecSupplyPointsServiceClient).to receive(:get).and_return(supply_point_response)
      allow(listener).to receive(:ack!)
      allow(listener).to receive(:publish)
      listener.work(message.to_json)
    end

    shared_examples_for 'always' do

      it 'requested the data for the correct mpan' do
        expect(ElecSupplyPointsServiceClient).to have_received(:get).with(message[:mpan], message[:date])
      end

      it 'should call ack!' do
        expect(listener).to have_received(:ack!)
      end
    end

    context 'when data is half hourly' do
      let(:supply_point_response) { {status: 200, body: {
          mpan_top_row: mpan_top_row,
          supply_point_reference: '1234-321',
          distribution_area: 'london',
          half_hourly: true,
          llf_class: '120',
          supply_capacity: 1600.0,
          customers: [
              {customer: 'test-customer', site_id: 'SITE1', site_name: 'the site', bands: [{a: 'the_band'}]},
              {customer: 'test-customer2', site_id: 'MYSITE', site_name: 'my site', bands: [{a: 'these_band'}]}
          ]
      }.to_json} }

      it_behaves_like 'always'

      it 'sends a profile.data.consumption.imported event with correct details for test-customer' do
        expected_message = {
            date: message[:date],
            data: data,
            customer: 'test-customer',
            mpan_top_row: mpan_top_row,
            supply_point_reference: '1234-321',
            distribution_area: 'london',
            llf_class: '120',
            bands: [{a: 'the_band'}],
            supply_capacity: 1600.0
        }
        expect(listener).to have_received(:publish).with(expected_message.to_json, routing_key: 'elec.hh.consumption.imported')
      end

     it 'sends a profile.data.consumption.imported event with correct details for test-customer2' do
        expected_message = {
            date: message[:date],
            data: data,
            customer: 'test-customer2',
            mpan_top_row: mpan_top_row,
            supply_point_reference: '1234-321',
            distribution_area: 'london',
            llf_class: '120',
            bands: [{a: 'these_band'}],
            supply_capacity: 1600.0
        }
        expect(listener).to have_received(:publish).with(expected_message.to_json, routing_key: 'elec.hh.consumption.imported')
      end

    end

    context 'when the data is not half hourly' do
      let(:supply_point_response) { {status: 200, body: {
          mpan_top_row: mpan_top_row,
          supply_point_reference: '1234-321',
          distribution_area: 'london',
          half_hourly: false,
          llf_class: '120',
          supply_capacity: 1600.0,
          customers: [
              {customer: 'test-customer', site_id: 'SITE1', site_name: 'the site', bands: [{a: 'band'}]}
          ]
      }.to_json} }

      it_behaves_like 'always'


      it 'sends a profile.non.half.hourly.data.consumption.available' do
        expected_message = {
            date: message[:date],
            data: data,
            customer: 'test-customer',
            mpan_top_row: mpan_top_row,
            supply_point_reference: '1234-321',
            distribution_area: 'london',
            llf_class: '120',
            bands: [{a: 'band'}],
            supply_capacity: 1600.0
        }
        expect(listener).to have_received(:publish).with(expected_message.to_json, routing_key: 'profile.non.half.hourly.data.consumption.available')
      end
    end

    context 'when the call to SupplyPointService fails' do
      it_behaves_like 'always'

      let(:supply_point_response) { {status: 404, body: {data: data}.to_json} }

      it 'should not publish a message' do
        expect(listener).to_not have_received(:publish)
      end
    end

  end
end