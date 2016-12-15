# Rules for Sample Management

# Sampler class
class Sampler
  def initialize
    @maid = Maid::Maid.new

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
    @dir_src = @dir_samples + '/src'
    @dir_music = @dir_src + '/music'
  end

  attr_reader :dir_root, :dir_in, :dir_samples, :dir_src, :dir_music

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
end

Maid.rules do
  @s = Sampler.new

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

  rule 'Sampler: move files to directories based on prefix' do
    dir_done = @s.dir_in + '/00001 done'
    prefixes = {
      'jazz'  => @s.dir_music + '/jazz',
      'orch'  => @s.dir_music + '/orch',
      'rnb'   => @s.dir_music + '/rnb',
      'movie' => @s.dir_src + '/movies',
      'tv'    => @s.dir_src + '/tv'
    }
    dir(dir_done + '/*.wav').each do |file|
      prefixes.each do |pre, dir|
        dir += '/'
        filename = File.basename(file)
        move(file, dir) if filename.start_with? '[' + pre + ']'
      end
    end
  end
end
