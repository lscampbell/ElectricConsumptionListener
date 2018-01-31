guard :rspec, cmd: "bundle exec rspec", all_on_start: true do

  watch(%r{^spec/.+\.rb$}) {'spec'}
  watch(%r{^lib/.+\.rb$}) {'spec'}
  watch('profile_listeners.rb') {'spec'}

end
