describe ProfileDataAvailableLossListener do
  context 'when profile.data.consumption.available message is received' do
    let(:listener) { ProfileDataAvailableLossListener.new }
    let(:path) { '/url_to_data/from/profile/repo' }
    let(:data) { [{'kwh' => 65}] }
    let(:date) { DateTime.new(2016, 1, 1) }
    let(:message) { {
        path: path,
        data: data,
        distribution_area: 'East-Midlands',
        llf_class: '123',
        customer: 'test-customer',
        supply_point_reference: '123456',
        date: date,
        bands: [{a: 'band'}],
        supply_capacity: 1200.0
    }.to_json }
    let(:calculated_loss_data) { ['kwh' => 80, 't_loss' => 432, 'd_loss' => 242, 't_loss_factor' => 234, 'd_loss_factor' => 789] }

    before :each do
      allow(listener).to receive(:ack!)
      allow(listener).to receive(:publish)
    end


    shared_examples_for 'always' do
      it 'will request loss data' do
        expect(LossCalculationServiceClient).to have_received(:post).with(date, 'east-midlands', '123', data)
      end

      it 'acknowledges the message' do
        expect(listener).to have_received(:ack!)
      end

    end

    context 'when everything is successfully' do
      before :each do
        allow(LossCalculationServiceClient).to receive(:post).and_return({status: 200, body: {data: calculated_loss_data}.to_json})
        allow(ProfileDataRepositoryClient).to receive(:post).and_return({status: 200, body: {data: [], url: '/blah'}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'post the calculated loss data back to the profile repo' do
        expect(ProfileDataRepositoryClient).to have_received(:post).with(path, {'data' => calculated_loss_data})
      end

      it 'sends a profile.data.loss.calculated message' do
        expected_body = {
            data: [],
            url: '/blah',
            distribution_area: 'East-Midlands',
            llf_class: '123',
            customer: 'test-customer',
            supply_point_reference: '123456',
            date: DateTime.new(2016, 1, 1),
            bands:[{a: 'band'}],
            supply_capacity: 1200.0
        }
        expect(listener).to have_received(:publish).with(expected_body.to_json, routing_key: 'elec.hh.loss.calculated.successfully')
      end
    end

    context 'when calculation fails' do
      before :each do
        allow(LossCalculationServiceClient).to receive(:post).and_return({status: 500, body: {error: ['error_message']}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'sends a profile.data.loss.calculated.failed message' do
        expect(listener).to have_received(:publish).with({error: ['error_message']}.to_json, routing_key: 'elec.hh.loss.calculated.failed')
      end
    end

    context 'when posting back to repo fails' do
      before :each do
        allow(LossCalculationServiceClient).to receive(:post).and_return({status: 200, body: {data: calculated_loss_data}.to_json})
        allow(ProfileDataRepositoryClient).to receive(:post).and_return({status: 500, body: {error: ['error_message']}.to_json})
        listener.work(message)
      end

      it_behaves_like 'always'

      it 'sends a profile.data.loss.calculated message' do

        expected_body = {
            error: ['error_message'],
            distribution_area: 'East-Midlands',
            llf_class: '123',
            customer: 'test-customer',
            supply_point_reference: '123456',
            date: DateTime.new(2016, 1, 1),
            bands:[{a:'band'}],
            supply_capacity: 1200.0
        }
        expect(listener).to have_received(:publish).with(expected_body.to_json, routing_key: 'elec.hh.loss.post_to_profile.failed')
      end
    end
  end

end