# Rules for Sample Management

# Sampler class
class Sampler
  def initialize(maid)
    @maid = maid

    @exts = %w(wav)

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
    @dir_src = @dir_samples + '/src'
    @dir_music = @dir_src + '/music'
  end

  attr_reader :dir_root, :dir_in, :dir_samples, :dir_src, :dir_music

  # Does the file have a valid extension?
  def allowed_ext(filename)
    ext = File.basename(filename)
    @exts.include? File.extname(ext).delete('.')
  end

  # Sanitize tags
  def sanitize_tags(tags)
    tags.map! do |tag|
      tag.delete!('-')
      tag.tr!('+', 'n')
      's.' + tag
    end
  end

  # Add tags to files within `dir_path` based on itself
  def tag_dirname(dir_path)
    dir_tag = sanitize_tags([dir_path.tr('/', '.')])
    dir_path = @dir_samples + '/' + dir_path
    @maid.dir(dir_path + '/**/*.wav').each do |file|
      @maid.add_tag(file, dir_tag)
    end
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

  # Rules for the Inbox directory
  watch @s.dir_in do
    rule 'Sampler: copy inbox filenames to Spotlight comments' do |mod, add|
      files = mod + add
      files.each do |file|
        next unless @s.allowed_ext(file)
        @s.filename_to_comment(file)
      end
    end
  end

  # Rules for the Done directory
  watch @s.dir_in + '/00001 done' do
    rule 'Sampler: tag each file in Done directory with `s`' do |_mod, add|
      add.each do |file|
        next unless @s.allowed_ext(file)
        add_tag(file, 's')
      end
    end

    rule 'Sampler: move files to directories based on prefix' do |mod, add|
      files = mod + add
      prefixes = {
        'jazz'  => @s.dir_music + '/jazz',
        'orch'  => @s.dir_music + '/orch',
        'rnb'   => @s.dir_music + '/rnb',
        'movie' => @s.dir_src + '/movies',
        'tv'    => @s.dir_src + '/tv'
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

    rule 'Sampler: copy inbox filenames to Spotlight comments' do
      dir(@s.dir_in + '/*.wav').each do |file|
        @s.filename_to_comment(file)
      end
    end
  end

  # Rules for the Samples directory
  watch @s.dir_samples do
    rule 'Sampler: tag based on directory names' do
      # Add basic `s` tag to every wav
      dir(@s.dir_samples + '/**/*.wav').each do |file|
        add_tag(file, 's')
      end

      # Tag basic types
      @s.tag_dirname 'field'
      @s.tag_dirname 'session'

      # Tag source types
      @s.tag_dirname 'src'
      %w(intv movies tv xxx radio radio/shortwave).each do |type_dir|
        @s.tag_dirname 'src/' + type_dir
      end

      # Tag music genres
      %w(orch electronic hiphop jazz rb rock).each do |genre_dir|
        @s.tag_dirname @s.dir_music + genre_dir
      end
    end
  end
end
