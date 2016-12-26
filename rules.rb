# Rules for Sample Management

# Sampler class
class Sampler
  # rubocop:disable Metrics/MethodLength
  def initialize(maid)
    @maid = maid

    @exts = %w(wav)

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_in_rxxd = @dir_in + '/00001 rxxd'
    @dir_in_out = @dir_in + '/00002 out'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
    @dir_src = @dir_samples + '/src'
    @dir_music = @dir_src + '/music'

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
      'src/xxx'
    ]
  end
  # rubocop:enable Metrics/MethodLength

  attr_reader :tag_dirs, :dir_root, :dir_in, :dir_in_rxxd, :dir_in_out,
              :dir_samples, :dir_src, :dir_music

  # Does the file have a valid extension?
  def allowed_ext(filename)
    ext = File.basename(filename)
    @exts.include? File.extname(ext).delete('.')
  end

  # Sanitize tags
  def sanitize_tags(tags)
    sanitized_tags = tags.map do |tag|
      tag = tag.delete('-')
      tag = tag.tr('/', '.')
      tag = tag.tr('+', 'n')
      's.' + tag
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
end

Maid.rules do
  @s = Sampler.new(self)
  @allowed_tag_namespaces = %w(
    insects
    perc
    strings
    vinyl
    vox
    woodwind
  )

  # Rules for the Ready directory
  watch @s.dir_in_rxxd do
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
        'rnb'   => @s.dir_music + '/rnb',
        'movie' => @s.dir_src + '/movies',
        'tv'    => @s.dir_src + '/tv',
        'yt'    => @s.dir_src + '/youtube'
      }
      files.each do |file|
        next unless @s.allowed_ext(file)
        prefixes.each do |pre, dir|
          dir += '/'
          filename = File.basename(file)
          move(file, dir) if filename.start_with? '[' + pre + ']'
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

  watch @s.dir_samples do
    rule 'Sampler: tag all samples with `s`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's') }
    end

    rule 'Sampler: add base tag to tags in allowed namespaces' do |mod, add|
      (mod + add).each do |file|
        tags(file).each do |tag|
          tag_base = tag.rpartition('.')[0]
          unpre_tag_base = tag_base.sub('s.', '')
          next if unpre_tag_base == 's'
          next unless @allowed_tag_namespaces.include? unpre_tag_base
          next if contains_tag?(file, tag_base)
          add_tag(file, tag_base)
        end
      end
    end
  end

  watch @s.dir_src do
    rule 'Sampler: tag all samples in `src`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's.src') }
    end
  end

  rule 'Sampler: Utility: verify `s` tag' do
    dir(@s.dir_samples + '/**/*.wav').each do |file|
      add_tag(file, 's')
    end
  end

  rule 'Sampler: Utility: verify `s.src` tag' do
    dir(@s.dir_src + '/**/*.wav').each do |file|
      add_tag(file, 's.src')
    end
  end

  rule 'Sampler: Utility: verify directory tags' do
    @s.tag_dirs.each do |tag_dir|
      tag_dir_path = @s.dir_samples + '/' + tag_dir
      tags = @s.dirname_tag(tag_dir)
      dir(tag_dir_path + '/**/*.wav').each do |file|
        add_tag(file, tags)
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
