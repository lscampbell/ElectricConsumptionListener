
def create_time(time_str)
  DateTime.parse("#{DateTime.new(2016, 1, 1).strftime('%d/%m/%Y')} #{time_str}")
end

describe ProfileDataAvailableChargeListener do
  context 'when elec.hh.*.calculated.successfully event is received' do
    let(:listener) { ProfileDataAvailableChargeListener.new }
    let(:path) { '/url_to_data/from/profile/repo' }
    let(:message) do
      {
        path:                   path,
        date:                   DateTime.new(2016, 1, 1),
        supply_point_reference: supply_point_ref,
        customer:               customer,
        llf_class:              '340',
        distribution_area:      'north',
        bands:                  [
                                  { name: 'Night', start: '2016-01-01T00:00:00+00:00', end: '2016-01-01T06:00:00+00:00', pence_per_kwh: 2.5 },
                                  { name: 'Day', start: '2016-01-01T06:00:00+00:00', end: '2016-01-01T18:00:00+00:00', pence_per_kwh: 5.0 },
                                  { name: 'Night', start: '2016-01-01T18:00:00+00:00', end: '2016-01-02T00:00:00+00:00', pence_per_kwh: 2.5 }
                                ],
        supply_capacity:        1500.0
      }.to_json
    end
    let(:customer){'test-customer'}
    let(:supply_point_ref) { '1234-321' }
    let(:date) { DateTime.new(2016, 01, 01) }
    let(:charges_path) { "/#{supply_point_ref}/charges/#{date}" }
    let(:expected_bands) do
      [
          {'name' => 'Night', 'start' => '2016-01-01T00:00:00+00:00', 'end' => '2016-01-01T06:00:00+00:00', 'pence_per_kwh' => 2.5},
          {'name' => 'Day', 'start' => '2016-01-01T06:00:00+00:00', 'end' => '2016-01-01T18:00:00+00:00', 'pence_per_kwh' => 5.0},
          {'name' => 'Night', 'start' => '2016-01-01T18:00:00+00:00', 'end' => '2016-01-02T00:00:00+00:00', 'pence_per_kwh' => 2.5}
      ]
    end
    let(:supply_point_info) do
      {
          bands: expected_bands,
          supply_capacity: 1500.0
      }
    end

    before :each do
      allow(listener).to receive(:ack!)
      allow(listener).to receive(:publish)
    end

    shared_examples_for 'always' do
      it 'retrieves profile data' do
        expect(ProfileDataRepositoryClient).to have_received(:get).with(path)
      end


      it 'should call ack!' do
        expect(listener).to have_received(:ack!)
      end
    end

    shared_examples_for 'calculation succeeded' do

      it 'posts to the charge repo' do
        expect(ChargeServiceClient).to have_received(:post).with(customer, supply_point_ref, date, {'bands' => data}, supply_point_info)
      end

      it 'should send a elec.hh.charges.calculated.successfully' do
        expected_body = {
            json: 'from repo',
            distribution_area: 'north',
            llf_class: '340',
            customer: 'test-customer',
            supply_point_reference: supply_point_ref,
            date: DateTime.new(2016, 1, 1),
            bands: expected_bands,
            supply_capacity: 1500.0
        }.to_json
        expect(listener).to have_received(:publish).with(expected_body, routing_key: 'elec.hh.charges.calculated.successfully')
      end
    end

    context 'when retrieving the profile data fails' do
      let(:data) { [] }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:get).and_return({status: 500, body: {errors: ['some error']}.to_json})
        allow(ChargeServiceClient).to receive(:post).and_return({status: 200, body: {json: 'from repo'}.to_json})
        listener.work(message)
      end

      it 'should publish a elec.hh.data.charges.profile.retrieval.failed event' do
        expect(listener).to have_received(:publish).with({errors: ['some error']}.to_json, routing_key: 'elec.hh.data.charges.profile.retrieval.failed')
      end

      it 'should not continue processing the charges' do
        expect(ChargeServiceClient).to_not have_received(:post)
      end

      it_behaves_like 'always'
    end

    context 'when duos has not been populated' do
      let(:data) { [{'kwh' => 65, 't_loss' => 1.01}] }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:get).and_return({status: 200, body: {bands: data}.to_json})
        allow(ChargeServiceClient).to receive(:post).and_return({status: 200, body: {json: 'from repo'}.to_json})
        listener.work(message)
      end


      it_behaves_like 'always'
      it_behaves_like 'calculation succeeded'

    end

    context 'when loss has not been populated' do
      let(:data) { [{'kwh' => 65, 'duos_band' => 'Green'}] }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:get).and_return({status: 200, body: {bands: data}.to_json})
        allow(ChargeServiceClient).to receive(:post).and_return({status: 200, body: {json: 'from repo'}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'
      it_behaves_like 'calculation succeeded'
    end

    context 'when everything is successful' do
      let(:data) { [{'kwh' => 65, 'duos_band' => 'Green', 't_loss' => 1.01}] }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:get).and_return({status: 200, body: {bands: data}.to_json})
        allow(ChargeServiceClient).to receive(:post).and_return({status: 200, body: {json: 'from repo'}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'
      it_behaves_like 'calculation succeeded'
    end

    context 'when posting to the charge repo fails' do
      let(:data) { [{'kwh' => 65, 'duos_band' => 'Green', 't_loss' => 1.01}] }
      before :each do
        allow(ProfileDataRepositoryClient).to receive(:get).and_return({status: 200, body: {bands: data}.to_json})
        allow(ChargeServiceClient).to receive(:post).and_return({status: 500, body: {errors: ['error from repo']}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'


      it 'should post the charges' do
        expect(ChargeServiceClient).to have_received(:post).with(customer, supply_point_ref, date, {'bands' => data}, supply_point_info)
      end


      it 'sends elec.hh.charges.calculated.failed message' do
        expected_body = {
            errors: ['error from repo'],
            distribution_area: 'north',
            llf_class: '340',
            customer: 'test-customer',
            supply_point_reference: supply_point_ref,
            date: DateTime.new(2016, 1, 1),
            bands: expected_bands,
            supply_capacity: 1500.0
        }
        expect(listener).to have_received(:publish).with(expected_body.to_json,
                                                         routing_key: 'elec.hh.charges.calculated.failed')
      end
    end
  end
end