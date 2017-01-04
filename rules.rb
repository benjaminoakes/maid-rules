# Rules for Sample Management

# Sampler class
class Sampler
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def initialize(maid)
    @maid = maid

    @exts = %w(wav)
    @tag_prefix = ''

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_in_proc = @dir_in + '/00001 processed'
    @dir_in_out = @dir_in + '/00002 out'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
    @dir_src = @dir_samples + '/src'
    @dir_music = @dir_src + '/music'
    @dir_stg_smp = @dir_root + '/00005 staging/00000 ALL SAMPLES'
    @dir_dvc_ot = @dir_root + '/00002 devices/octatrack'

    @tag_dirs = [
      'field',
      'session',
      'src/intv',
      'src/movies',
      'src/music',
      'src/music/electronic',
      'src/music/hiphop',
      'src/music/jazz',
      'src/music/orch',
      'src/music/rock',
      'src/music/rnb',
      'src/radio',
      'src/radio/shortwave',
      'src/tv',
      'src/youtube'
    ]
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  attr_reader :tag_dirs, :dir_in, :dir_in_proc, :dir_in_out, :dir_samples,
              :dir_src, :dir_music, :dir_stg_smp, :dir_dvc_ot

  # Does the file have a valid extension?
  def allowed_ext(filename)
    @exts.include? file_ext(filename)
  end

  # Get the file extension for a given file, without the dot
  def file_ext(filename)
    File.extname(filename).delete('.')
  end

  # Sanitize tags
  def sanitize_tags(tags)
    sanitized_tags = tags.map do |tag|
      tag = tag.delete('-')
      tag = tag.tr('/', '.')
      tag = tag.tr('+', 'n')
      @tag_prefix + tag
    end
    sanitized_tags
  end

  # Set up vars for directory tagging
  def dirname_tag(dir)
    tag = dir
    case tag
    when 'src/music/orch'
      tag = 'orch'
    end
    sanitize_tags([tag])
  end

  # Copy a filename to the file's macOS Spotlight comment
  def filename_to_comment(path)
    filename = File.basename(path)
    # rubocop:disable Metrics/LineLength
    command = "osascript -e 'on run {f, c}' -e 'tell app \"Finder\" to set comment of (POSIX file f as alias) to c' -e end "
    # rubocop:enable Metrics/LineLength
    command += "\"#{path}\" \"#{filename}\""
    @maid.logger.info("copy filename to spotlight comments for #{path}")
    @maid.cmd(command) unless @maid.file_options[:noop]
  end

  # Set a file to hidden in Finder
  def hide_file(path)
    @maid.cmd("chflags hidden \"#{path}\"")
  end

  # Create a symbolic link
  def symlink(src, dest)
    # Use the `f` flag to create a new link even if one already exists
    cmd = "ln -sf \"#{src}\" \"#{dest}\""
    @maid.logger.info("symlink \"#{src}\" to \"#{dest}\"")
    @maid.cmd(cmd) unless @maid.file_options[:noop]
  end
end

Maid.rules do
  @s = Sampler.new(self)
  @allowed_tag_namespaces = %w(
    insects
    perc
    strings
    vinyl
    vox
  )
  @hide_exts = %w(
    pkf
    asd
  )

  # Rules for the Ready directory
  watch @s.dir_in_proc do
    rule 'Sampler: copy filenames to Spotlight comments' do |mod, add|
      files = mod + add
      files.each do |file|
        next unless @s.allowed_ext(file)
        # Don't copy the filename to the comment if it has any uppercase letters
        name = File.basename(file)
        next unless (name == name.downcase) || (name.start_with? '[yt]')
        # Copy filename to comment
        @s.filename_to_comment(file)
      end
    end
  end

  # Rules for the Out directory
  watch @s.dir_in_out do
    rule 'Sampler: move files to directories based on prefix' do |mod, add|
      files = mod + add
      prefixes = {
        'jazz'  => @s.dir_music + '/jazz',
        'orch'  => @s.dir_music + '/orch',
        'rock'  => @s.dir_music + '/rock',
        'rnb'   => @s.dir_music + '/rnb',
        'movie' => @s.dir_src + '/movies',
        'tv'    => @s.dir_src + '/tv',
        'yt'    => @s.dir_src + '/youtube',
        'field' => @s.dir_samples + '/field'
      }
      files.each do |file|
        next unless @s.allowed_ext(file)
        prefixes.each do |pre, dir|
          dir += '/'
          pre = '[' + pre + '] '
          next unless File.basename(file).start_with? pre
          new_file = file.sub(pre, '')
          rename(file, new_file)
          move(new_file, dir)
        end
      end
    end
  end

  @s.tag_dirs.each do |tag_dir|
    tag_dir_path = @s.dir_samples + '/' + tag_dir
    tags = @s.dirname_tag tag_dir

    watch tag_dir_path do
      rule "Sampler: tag #{tags} based on directory name" do |mod, add|
        files = mod + add
        files.each do |chg_file|
          add_tag(chg_file, tags)
        end
      end
    end
  end

  watch @s.dir_in do
    rule 'Hide files with certain extensions' do |_mod, add|
      add.each do |file|
        next unless @hide_exts.include? @s.file_ext(file)
        @s.hide_file(file)
      end
    end
  end

  watch @s.dir_samples do
    rule 'Sampler: add base tag to tags in allowed namespaces' do |mod, add|
      (mod + add).each do |file|
        tags(file).each do |tag|
          tag_base = tag.rpartition('.')[0]
          next if tag_base == 's'
          next unless @allowed_tag_namespaces.include? tag_base
          next if contains_tag?(file, tag_base)
          add_tag(file, tag_base)
        end
      end
    end

    rule 'Hide files with certain extensions' do |_mod, add|
      add.each do |file|
        next unless @hide_exts.include? @s.file_ext(file)
        @s.hide_file(file)
      end
    end

    rule 'Create symlinks to files in the ALL directory' do |mod, add, del|
      all = (mod + add + del)
      all.each do |file|
        next unless @s.allowed_ext(file)
        fn = File.basename(file)
        dest = @s.dir_stg_smp + '/' + fn
        if del.include? file
          # We need to use the `rm` command here because `trash()` will follow
          # the symlink and attempt to trash the original file
          logger.info("removing symlink #{dest}")
          cmd("rm \"#{dest}\"")
          next
        end
        @s.symlink(file, dest)
      end
    end
  end

  watch @s.dir_dvc_ot do
    rule 'Sampler: move OT meta files to sample dir' do |_mod, add|
      add.each do |file|
        next unless @s.file_ext(file) == 'ot'
        next if File.symlink? file
        fn = File.basename(file)
        smp_fn = fn.gsub('.ot', '.wav')
        # Find the corresponding sample file in the samples directory
        find(@s.dir_samples).grep(/#{smp_fn}$/) do |smp|
          smp_dir = File.dirname(smp) + '/'
          # Move the OT metadata file to the sample's directory
          move(file, smp_dir)
          # Symlink the OT file from its new home back to the directory where we
          # found it originally
          @s.symlink(smp_dir + fn, file)
        end
      end
    end
  end

  # rule 'Sampler: Utility: remove tags from all files' do
  #   dir(@s.dir_samples + '/**/*').each do |file|
  #     tags = tags(file)
  #     remove_tag(file, tags)
  #   end
  # end
end
