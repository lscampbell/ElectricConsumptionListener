require 'json'
require 'logger'
describe ProfileImportListener do
  context 'when "profile.data.consumption.imported" event is received' do
    let(:listener) { ProfileImportListener.new }
    let(:data) { [{'kwh' => 65}] }
    let(:message) { {
        customer: 'test-customer',
        mpan_top_row: mpan_top_row,
        supply_point_reference: '1234-321',
        distribution_area: 'london',
        llf_class: '120',
        date: DateTime.new(2016, 01, 01),
        data: data,
        bands: [{a: 'band'}],
        supply_capacity: 1200.0
    }.to_json }
    let(:returned_body) { {status: 'OK', path: '/some/url/to/data', data: data}.to_json }
    let(:failed_body) { {errors: ['error 1', 'error 2']}.to_json }


    shared_examples 'always' do
      it 'posts to the profile repo' do
        expect(ProfileDataRepositoryClient).to have_received(:post).with("/test-customer/supply-points/1234-321/2016-01-01", {data: data})
      end

      it 'acknowledges the message' do
        expect(listener).to have_received(:ack!)
      end
    end

    context 'when posting the data to profile profile repo is successful' do
      let(:mpan_top_row) { '001234-5432' }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:post).and_return(status: 200, body: returned_body)
        allow(listener).to receive(:publish)
        allow(listener).to receive(:ack!)
        listener.work(message)

      end

      it_behaves_like 'always'

      it 'sends a profile.data.consumption.available message' do
        expected = JSON.parse(returned_body).merge(
            distribution_area: 'london',
            llf_class: '120',
            customer: 'test-customer',
            supply_point_reference: '1234-321',
            date: DateTime.new(2016, 1, 1),
            bands: [{a: 'band'}],
            supply_capacity: 1200.0
        ).to_json
        expect(listener).to have_received(:publish).with(expected, routing_key: 'elec.hh.consumption.available')
      end

    end

    context 'when posting to profile repo fails' do
      let(:mpan_top_row) { '1234-321' }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:post).and_return(status: 500, body: failed_body)
        allow(listener).to receive(:publish)
        allow(listener).to receive(:ack!)
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'sends a profile.data.consumption.import.save.failed message' do
        expect(listener).to have_received(:publish).with(failed_body,
                                                         routing_key: 'profile.data.consumption.import.save.failed')
      end
    end
  end
end
