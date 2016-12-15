# Rules for Sample Management

# Sampler class
class Sampler
  def initialize
    @maid = Maid::Maid.new

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_samples = @dir_root + '/00001 library/00002 samples'
  end

  attr_reader :dir_root, :dir_in, :dir_samples

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
  rule 'Sampler: tag based on directory names' do
    s = Sampler.new

    # Add basic `s` tag to every wav
    dir(s.dir_samples + '/**/*.wav').each do |file|
      add_tag(file, 's')
    end

    # Tag basic types
    s.tag_dirname 'field'
    s.tag_dirname 'session'

    # Tag source types
    s.tag_dirname 'src'
    %w(intv movies tv xxx radio radio/shortwave).each do |type_dir|
      s.tag_dirname 'src/' + type_dir
    end

    # Tag music genres
    %w(classical electronic hiphop jazz rb rock).each do |genre_dir|
      s.tag_dirname 'src/music/' + genre_dir
    end
  end
end
