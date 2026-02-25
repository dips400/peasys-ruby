Gem::Specification.new do |s|
  s.name        = 'peasys-ruby'
  s.version     = '2.0.0'
  s.authors     = ['DIPS']
  s.summary     = 'ActiveRecord adapter for IBM Db2 on IBM i via Peasys service'
  s.description = 'Ruby client and ActiveRecord adapter for IBM Db2 on IBM i (AS/400) via the Peasys middleware service'
  s.email       = 'dips@dips400.com'
  s.files       = Dir['lib/**/*.rb']
  s.require_paths = ['lib']
  s.homepage    = 'https://github.com/dips400/peasys-ruby'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.1.0'

  s.add_dependency 'activerecord', '>= 7.2', '< 8.0'

  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'minitest', '~> 5.0'
end
