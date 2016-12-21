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

  # Rules for the Ready directory
  watch @s.dir_in + '/00000 ready' do
    rule 'Sampler: copy inbox filenames to Spotlight comments' do |mod, add|
      files = mod + add
      files.each do |file|
        next unless @s.allowed_ext(file)
        # Don't copy the filename to the comment if it has any uppercase letters
        # rubocop:disable Style/CaseEquality
        next unless file === file.downcase
        # rubocop:enable Style/CaseEquality
        @s.filename_to_comment(file)
      end
    end
  end

  # Rules for the Out directory
  watch @s.dir_in + '/00001 out' do
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

  @tag_dirs.each do |tag_dir|
    tag_dir_path = @s.dir_samples + '/' + tag_dir
    tag = tag_dir
    case tag_dir
    when 'src/music/orch'
      tag = 'orch'
    end
    tag = @s.sanitize_tags([tag])

    watch tag_dir_path do
      rule "Sampler: tag #{tag} based on directory name" do |mod, add|
        files = mod + add
        files.each do |chg_file|
          add_tag(chg_file, tag)
        end
      end
    end

    repeat '12h' do
      rule "Sampler: verify #{tag}" do
        dir(tag_dir_path + '/**/*.wav').each do |file|
          add_tag(file, tag)
        end
      end
    end
  end

  watch @s.dir_samples do
    rule 'Sampler: tag all samples with `s`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's') }
    end
  end

  watch @s.dir_src do
    rule 'Sampler: tag all samples in `src`' do |mod, add|
      (mod + add).each { |file| add_tag(file, 's.src') }
    end
  end

  # Schedule cleanup for untagged files
  #
  # Sometimes the watch rules fail to tag everything fully.
  repeat '12h' do
    rule 'Sampler: verify `s` tag' do
      dir(@s.dir_samples + '/**/*.wav').each do |file|
        add_tag(file, 's')
      end
    end

    rule 'Sampler: verify `s.src` tag' do
      dir(@s.dir_src + '/**/*.wav').each do |file|
        add_tag(file, 's.src')
      end
    end
  end

  rule 'Sampler: Utility: remove tags from all files' do
    dir(@s.dir_samples + '/**/*').each do |file|
      tags = tags(file)
      remove_tag(file, tags)
    end
  end
end
