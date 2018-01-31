require 'json'

describe ProfileDataAvailableDuosListener do
  context 'when profile.data.consumption.available message is received' do
    let(:listener) { ProfileDataAvailableDuosListener.new }
    let(:path) { '/url_to_data/from/profile/repo' }
    let(:data) { [{'kwh' => 65}] }
    let(:message) { {
        path: path,
        data: data,
        distribution_area: 'East-Midlands',
        llf_class: '123',
        customer: 'test-customer',
        supply_point_reference: '123456',
        date: DateTime.new(2016, 1, 1),
        bands:[{another:'band'}],
        supply_capacity: 1400.0
    }.to_json }
    let(:calculated_duos_data) do
      {'bands' => ['kwh' => 65, 'duos_band' => 'Green', 'duos_unit_charge' => 10.86]}
    end

    before :each do
      allow(listener).to receive(:ack!)
      allow(listener).to receive(:publish)
    end

    shared_examples_for 'always' do
      it 'requests the duos data' do
        expect(DuosCalculationServiceClient).to have_received(:post).with('east-midlands', '123', data)
      end

      it 'acknowledges the message' do
        expect(listener).to have_received(:ack!)
      end
    end

    context 'when the everything is successful' do
      before :each do
        allow(DuosCalculationServiceClient).to receive(:post).and_return({status: 200, body: calculated_duos_data.to_json})
        allow(ProfileDataRepositoryClient).to receive(:post).and_return({status: 200, body: {some: 'json'}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'posts the calculated duos data back to the profile repo' do
        expect(ProfileDataRepositoryClient).to have_received(:post).with("#{path}/duos", calculated_duos_data)
      end

      it 'sends a elec.hh.duos.calculated.successfully message' do
        expected_body = {
            some: 'json',
            distribution_area: 'East-Midlands',
            llf_class: '123',
            customer: 'test-customer',
            supply_point_reference: '123456',
            date: DateTime.new(2016, 1, 1),
            bands:[{another:'band'}],
            supply_capacity: 1400.0
        }
        expect(listener).to have_received(:publish).with(expected_body.to_json, routing_key: 'elec.hh.duos.calculated.successfully')
      end
    end

    context 'when the loss calculation fails' do
      before :each do
        allow(DuosCalculationServiceClient).to receive(:post).and_return({status: 500, body: {errors: ['error message']}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'sends a elec.hh.duos.calculation.failed message' do
        expect(listener).to have_received(:publish).with({errors: ['error message']}.to_json, routing_key: 'elec.hh.duos.calculation.failed')
      end
    end

    context 'when posting back to profile repo fails' do
      before :each do
        allow(DuosCalculationServiceClient).to receive(:post).and_return({status: 200, body: calculated_duos_data.to_json})
        allow(ProfileDataRepositoryClient).to receive(:post).and_return({status: 500, body: {errors: ['error message']}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'sends a elec.hh.duos.post_to_profile.failed message' do

        expected_body = {
            errors: ['error message'],
            distribution_area: 'East-Midlands',
            llf_class: '123',
            customer: 'test-customer',
            supply_point_reference: '123456',
            date: DateTime.new(2016, 1, 1),
            bands:[{another:'band'}],
            supply_capacity: 1400.0
        }
        expect(listener).to have_received(:publish).with(expected_body.to_json, routing_key: 'elec.hh.duos.post_to_profile.failed')
      end
    end
  end
end