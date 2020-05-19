# RSpec.describe Pixie do
#   it 'Has a version number' do
#     gem_dir = "#{File.dirname( File.expand_path __FILE__ )}/.."
#     version = %x[ bash -c 'source #{gem_dir}/bin/dockerise && gem_guess_version #{gem_dir}/pixie.gemspec' ].chomp
#     expect( Pixie.new( Pixie::Logging::QUIET ).gem_spec.version.to_s ).to eq version
#   end
#
#   it 'Does something useful' do
#     expect(false).to eq(false)
#   end
# end
