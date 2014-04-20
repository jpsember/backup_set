require 'backup_set'
require 'js_base/js_test'

class TestBackupSet < JSTest

  def setup
    super
    enter_test_directory
    self.swizzler.add('BackupSet','get_home_dir'){'.'}
  end

  def test_swizzled_backup_dir
    bs = BackupSet.new('_backupset_test_prefix_', '../sample_files')
    backup_dir = bs.backup_dir
    assert(File.directory?(backup_dir))
    ap = File.absolute_path(backup_dir)
    assert(ap.index('/test'))
  end

  def test_create_backupset
    bs = BackupSet.new('_backupset_test_prefix_', '../sample_files')

    backup_dir = bs.backup_dir
    assert(File.directory?(backup_dir))
    base = File.basename(backup_dir)
    assert(base.start_with?('_backup'))

    files = BackupSet.get_files_within_dir(bs.base_dir)
    assert(files.size >= 3)

    files.each do |path|
      bs.backup_file(path)
      backup_path = File.join(backup_dir,path)
      assert(File.exist?(backup_path))
    end
  end

  def test_sanitize
    assert_equal('abcd',BackupSet.sanitize_for_path('abcd'))
    assert_equal('ab_c_d',BackupSet.sanitize_for_path('ab/c\\d'))
  end

end

