#!/usr/bin/env ruby

# Support making rotating backups in hidden directories

require 'js_base'

class BackupSet

  # backup_name : name to form backups directory from
  # base_directory : directory containing files to be backed up; if nil, uses current directory
  # max_current_backup_minutes : maximum age of backup directory to be considered 'current'; if not current,
  #   a new one is made
  # expired_backup_days : if > 0, backup directories older than this number of days are deleted
  #
  def initialize(backup_name,base_directory=nil,max_current_backup_minutes=20,expired_backup_days=20)
    base_directory ||= ""
    @base_abs_dir = abs_path_current_dir(base_directory)
    sets_dir = get_backup_sets_dir(backup_name,true)

    backup_dir_list = get_backup_dir_list(sets_dir)
    if expired_backup_days != 0
      delete_expired_backups(backup_dir_list, expired_backup_days)
    end
    @backup_abs_dir = find_current_backup_dir(sets_dir,backup_dir_list, max_current_backup_minutes)
  end

  # Copy a file to the backup directory, if no such file already exists there
  # (e.g. won't replace an older version of the file with a newer one)
  #
  def backup_file(file_path)
    file_path = abs_path_relative_to_base(file_path)
    file_rel_path = path_relative_to_abs_dir(file_path,@base_abs_dir)
    backup_file_path = File.join(@backup_abs_dir,file_rel_path)
    if !File.exist?(backup_file_path)
      # Create directories, if necessary
      FileUtils::mkdir_p(File.dirname(backup_file_path))
      # Copy file to backup
      FileUtils::cp(file_path,backup_file_path)
    end
  end

  def base_dir
    @base_abs_dir
  end

  def backup_dir
    @backup_abs_dir
  end

  # Determine the directory where backup sets would be constructed
  #
  def get_backup_sets_dir(backup_name,create_if_missing=true)
    backup_name = BackupSet.sanitize_for_path(backup_name)
    dir = File.join(get_home_dir(),"._backupset_#{backup_name}_")
    if create_if_missing && !File.directory?(dir)
      Dir.mkdir(dir)
    end
    dir
  end

  # Get list of all files in this backup set
  # Returns array of paths relative to backup_dir
  #
  def get_backedup_files
    BackupSet.get_files_within_dir(backup_dir)
  end

  # Get user's home directory; exposed for unit tests
  #
  def get_home_dir
    Dir.home
  end

  # Get suffix to put in backup directory, based on time; exposed for unit tests
  #
  def get_backup_dir_suffix
    Time.now.strftime('%Y%m%d-%H%M%S')
  end


  private


  BACKUP_SET_DIR_PREFIX = "_backups_";

  def get_files_aux(file_list, dir)

    get_files_aux(file_list,backup_dir)
  end

  def abs_path_current_dir(path)
    abs_path_relative_to_abs_dir(path,FileUtils.pwd)
  end

  def abs_path_relative_to_base(path)
    abs_path_relative_to_abs_dir(path,@base_abs_dir)
  end

  def abs_path_relative_to_abs_dir(path,relative_to_path)
    pathname = Pathname.new(path)
    if !pathname.absolute?
      rel_pathname = Pathname.new(relative_to_path)
      pathname = rel_pathname.join(pathname)
    end
    pathname.to_path
  end

  def path_relative_to_abs_dir(abs_path,dir)
    abs_pathname = Pathname.new(abs_path)
    dir_pathname = Pathname.new(dir)
    abs_pathname.relative_path_from(dir_pathname).to_path
  end

  def delete_expired_backups(backup_dir_list,expired_backup_days)
    retained = []
    curr_time_sec = Time.now.to_i
    cutoff_time_sec = curr_time_sec- expired_backup_days * 24 * 3600
    backup_dir_list.each do |backup_dir|
      dir_time = File.mtime(backup_dir).to_i
      if dir_time < cutoff_time_sec
        FileUtils.rm_rf(backup_dir)
      else
        retained << backup_dir
      end
    end
    backup_dir_list.replace(retained)
  end

  def find_current_backup_dir(backup_sets_dir,backup_dir_list, max_current_backup_minutes)
    nearest_mt_sec = nil
    nearest_path = nil

    recent_secs = max_current_backup_minutes * 60

    curr_time = Time.now
    cutoff_sec = curr_time.to_i - recent_secs

    backup_dir_list.each do |backup_dir|
      mt = File.mtime(backup_dir)
      mt_sec = mt.to_i

      next if mt_sec < cutoff_sec

      if !nearest_mt_sec || mt_sec > nearest_mt_sec
        nearest_mt_sec = mt_sec
        nearest_path = backup_dir
      end
    end

    if !nearest_path
      nearest_path = File.join(backup_sets_dir,BACKUP_SET_DIR_PREFIX+get_backup_dir_suffix.to_s)
      Dir.mkdir(nearest_path)
    else
      # Update modification time of most recent directory
      FileUtils::touch(nearest_path)
    end
    nearest_path
  end

  # Get list of directories that are backup directories for this set
  #
  def get_backup_dir_list(backup_sets_dir)
    dir_list = []
    file_list = Dir.entries(backup_sets_dir)
    file_list.each do |x|
      next if x == '.' || x == '..'
      next if !x.start_with?(BACKUP_SET_DIR_PREFIX)
      dpath = File.join(backup_sets_dir,x)
      next if !File.directory?(dpath)
      dir_list << dpath
    end
     dir_list
  end


  # Get list of files within a directory, search recursively
  #
  # root_dir directory to examine; if Pathname, returns Pathnames; else strings
  # relative_to_root_dir if true, returns paths relative to root_dir; else, absolute
  #
  def self.get_files_within_dir(root_dir, relative_to_root_dir=true)
    is_pathname = root_dir.is_a? Pathname
    root_pathname = is_pathname ? root_dir : Pathname.new(root_dir)
    list = []
    get_files_within_pathname(root_pathname,list)
    if relative_to_root_dir
      list.map!{|x| x.relative_path_from(root_pathname)}
    end
    if !is_pathname
      list.map!{|x| x.to_path}
    end
    list
  end

  def self.sanitize_for_path(s)
    s2 = ''
    s.each_char do |c|
      if !(c =~ /[A-Za-z0-9_]/)
        c = '_'
      end
      s2 << c
    end
    s2
  end

  def self.get_files_within_pathname(current_pathname, pathname_list)
    current_pathname.children.each do |child|
      if child.file?
        pathname_list << child
      elsif child.directory?
        get_files_within_pathname(child, pathname_list)
      end
    end
  end

end

