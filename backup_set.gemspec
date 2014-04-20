require 'rake'

Gem::Specification.new do |s|
  s.name        = 'backup_set'
  s.version     = '0.0.0'
  s.date        = '2013-12-04'
  s.summary     = "Creates hidden backups of files in home directory"
  s.description = <<-EOF
    Maintains backup copies of a directory, by copying the directory (and its
    subdirectories) to a hidden file in the user's home directory.  This
    allows 'emergency' recovery of files that have been modified or deleted by a
    client program.
    The gem maintains numerous versions of the backed-up files, based upon the time the
    backup is generated.
EOF
  s.authors     = ["Jeff Sember"]
  s.email       = 'jpsember@gmail.com'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]
  s.homepage = 'http://www.cs.ubc.ca/~jpsember'
  s.test_files  = Dir.glob('test/*.rb')
  s.license     = 'MIT'
  s.add_runtime_dependency 'js_base', '>= 1.0.0'
end
