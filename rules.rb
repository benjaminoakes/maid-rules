# Rules for Sample Management

# Sampler class
class Sampler
  def initialize(maid)
    @maid = maid

    @exts = %w(ot wav)
    @tag_prefix = ''

    @dir_root = '/Users/syadasti/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_in_proc = @dir_in + '/00001 processed'
    @dir_in_out = @dir_in + '/00002 out'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
  end
  # rubocop:enable Metrics/MethodLength

  attr_reader :dir_in, :dir_in_proc, :dir_in_out, :dir_samples

  # Does the file have a valid extension?
  def allowed_ext(filename)
    @exts.include? file_ext(filename)
  end

  # Get the file extension for a given file, without the dot
  def file_ext(filename)
    File.extname(filename).delete('.')
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
  @dict = {
    'Amb'  => 'ambient',
    'Atm'  => 'atmosphere',
    'Bk'   => 'break',
    'Bs'   => 'bass',
    'Drn'  => 'drone',
    'Drm'  => 'drums',
    'Fd'   => 'field',
    'Gc'   => 'glitch',
    'Grn'  => 'grain',
    'Jz'   => 'src.music.jazz',
    'Nz'   => 'noise',
    'Oq'   => 'src.music.orch',
    'Strn' => 'strings',
    'Pc'   => 'perc',
    'Rdo'  => 'src.radio',
    'Rb'   => 'src.music.rnb',
    'Rk'   => 'src.music.rock',
    'Syn'  => 'synth',
    'Ttb'  => 'vinyl.turntablism',
    'Vx'   => 'vox'
  }
  @allowed_tag_namespaces = %w(
    drums
    insects
    perc
    src
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
      prefixes = %w(jazz orch rock rnb field)
      files.each do |file|
        next unless @s.allowed_ext(file)
        prefixes.each do |pre|
          dir = pre
          pre = '[' + pre + '] '
          fn = File.basename(file)
          next unless fn.start_with? pre
          dir = 'orchestral -- strings' if dir == 'orch'
          dir = @s.dir_samples + '/-- ' + dir + ' --/'
          unless File.directory?(dir)
            fail_msg = "#{dir} does not exist! File #{fn} not moved."
            logger.info(fail_msg)
            next
          end
          move(new_file, dir)
        end
      end
    end
  end

  # Watch the "In" directory
  watch @s.dir_in do
    rule 'Hide files with certain extensions' do |_mod, add|
      add.each do |file|
        next unless @hide_exts.include? @s.file_ext(file)
        @s.hide_file(file)
      end
    end
  end

  # Watch the "Samples" directory
  watch @s.dir_samples do
    rule 'Sampler: tag based on filename codes' do |mod, add|
      (mod + add).each do |file|
        @dict.each do |key, tag|
          add_tag(file, tag) if File.basename(file).include? key
        end
      end
    end

    rule 'Sampler: add base tag to tags in allowed namespaces' do |mod, add|
      (mod + add).each do |file|
        tags(file).each do |tag|
          tag_parts = tag.split('.')
          next unless @allowed_tag_namespaces.include? tag_parts[0]
          next if contains_tag?(file, tag_parts[0])
          tag_parts.each_index do |i|
            unless i.zero?
              i_prev = i - 1
              tag_parts[i] = tag_parts[i_prev] + '.' + tag_parts[i]
            end
            add_tag(file, tag_parts[i])
          end
        end
      end
    end

    rule 'Hide files with certain extensions' do |_mod, add|
      add.each do |file|
        next unless @hide_exts.include? @s.file_ext(file)
        @s.hide_file(file)
      end
    end
  end
end
