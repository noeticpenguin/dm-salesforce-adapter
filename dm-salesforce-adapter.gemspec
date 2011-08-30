Gem::Specification.new do |s|
  s.name             = "dm-salesforce-adapter"
  s.version          = "1.0.4.rc1"
  s.platform         = Gem::Platform::RUBY
  s.has_rdoc         = true
  s.extra_rdoc_files = ["README.markdown", "LICENSE"]
  s.summary          = "A DataMapper 1.1.x adapter to the Salesforce API"
  s.description      = s.summary
  s.authors          = [ "Jordan Ritter", "Tim Carey-Smith", "Andy Delcambre", "Yehuda Katz"]
  s.email            = "jpr5@cloudcrowd.com"
  s.homepage         = "http://github.com/cloudcrowd/dm-salesforce-adapter"

  s.add_dependency "httpclient",     " =2.1.5.2"
  s.add_dependency "data_objects",   "~> 0.10.6"
  s.add_dependency "dm-core",        "~> 1.1.0"
  s.add_dependency "dm-validations", "~> 1.1.0"
  s.add_dependency "dm-types",       "~> 1.1.0"
  s.add_dependency "soap4r-ruby1.9", "~> 2.0.1"

  s.require_path = 'lib'
  s.files        = %w(LICENSE README.markdown Rakefile) + Dir.glob("lib/**/*")
end
