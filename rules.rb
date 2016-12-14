# Rules for Sample Management

# Sampler class
class Sampler
  def initialize
    @maid = Maid::Maid.new

    @dir_root = '/Users/montchr/Music/0-sounds-0'
    @dir_in = @dir_root + '/00000 in'
    @dir_samples = @dir_root + '/00001 library copy/00002 samples'
    @tags = ['s']
  end

  attr_reader :dir_root, :dir_in, :dir_samples

  def get_subdirs(root)
    Dir.entries(root).select do |subdir|
      path = File.join(root, subdir)
      File.directory?(path) && !(subdir == '.' || subdir == '..')
    end
  end

  def prepare_tags(tags)
    tags.map! do |tag|
      tag.delete!('-')
      tag.tr!('+', 'n')
      's.' + tag
    end
    tags + @tags
  end

  def add_tags(dir_path, allowed_names, subdirs = false)
    if subdirs
      get_subdirs(dir_path).each do |subdir_name|
        subdir_path = dir_path + '/' + subdir_name
        tag_dirname(subdir_path, allowed_names)
      end
    else
      tag_dirname(dir_path, allowed_names)
    end
  end

  private

  def tag_dirname(dir_path, allowed_names)
    dir_name = File.basename(dir_path)
    @maid.dir(dir_path + '/**/*.wav').each do |file|
      next unless allowed_names.include? dir_name
      tags = prepare_tags([dir_name])
      @maid.add_tag(file, tags)
    end
  end
end

Maid.rules do
  rule 'Sampler: tag based on directory names' do
    s = Sampler.new

    dir_root_allowed = %w(field radio session)
    s.add_tags(s.dir_samples, dir_root_allowed, subdirs: true)

    # Tag music genres
    dir_music_allowed_names = ['classical', 'electronic', 'hip-hop',
                               'jazz', 'r+b', 'rock']
    dir_music = s.dir_samples + '/src/music'
    s.add_tags(dir_music, dir_music_allowed_names, subdirs: true)
  end
end
