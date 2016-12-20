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
      tag.tr!('/', '.')
      tag.tr!('+', 'n')
      's.' + tag
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
  end

  watch @s.dir_samples do
    rule 'Sampler: tag based on directory names' do |mod, add|
      files = mod + add
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

      @tag_dirs.each do |dir|
        files.each do |chg_file|
          next unless chg_file.include? dir
          tag = dir

          case dir
          when 'src/music/orch'
            tag = 'orch'
          end

          add_tag(chg_file, @s.sanitize_tags([tag]))
        end
      end
    end

    rule 'Sampler: tag all samples with `s`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's') }
    end
  end

  watch @s.dir_src do
    rule 'Sampler: tag all samples in `src`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's.src') }
    end
  end

  rule 'Sampler: Utility: remove tags from all files' do
    dir(@s.dir_samples + '/**/*').each do |file|
      tags = tags(file)
      remove_tag(file, tags)
    end
  end
end
