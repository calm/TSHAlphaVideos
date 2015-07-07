desc "convert rgba mov into rgb mp4 and alpha mp4"
task :split_mov do
  fail 'This task requires MPlayer to be installed; run "brew install mplayer" and try again.' unless mplayer_installed?
  fail 'This task requires AVAnimatorUtils to be in your PATH.  Look here http://www.modejong.com/AVAnimator/utils.html' unless animator_utils_installed?

  # parse file paths
  base_mov_path = ARGV[1] # first arg is absolute path to the unpremultiplied (straight) .mov with alpha channel
  crf = ARGV.fetch(2, 1) # optional crf determines quality.  1 is best, 51 is worst
  make_half_res = ARGV.fetch(3, false) # some android phones require a smaller memory footprint

  base_name = File.basename(base_mov_path, '.*')
  base_dir = File.dirname(base_mov_path) + '/'
  extension = File.extname(base_mov_path)

  mov_extension = '.mov'
  mvid_extension = '.mvid'

  if extension != mov_extension
    puts "cannot scrub file of type #{extension}, must me #{mov_extension}"
    return
  end

  # copy .mov into a temp directory
  temp_dir = "#{base_name}_temp"
  temp_path = "#{Dir.home}/Desktop/#{temp_dir}/"
  FileUtils.mkpath temp_path
  temp_mov_name = base_name + mov_extension
  temp_mov_path = temp_path + base_name + mov_extension
  temp_mvid_name = base_name + mvid_extension

  puts `rm -rf #{temp_path}`
  puts `mkdir #{temp_path}`
  puts `cp #{base_mov_path} #{temp_mov_path}`

  pwd = Dir.pwd
  Dir.chdir(temp_path)

  # do the compression to mp4, stripping alpha
  puts `mplayer -vo png:alpha #{temp_mov_name}` # split into individual pngs, 30fps

  all_files = Dir.entries("#{temp_path}")

  puts `mvidmoviemaker 00000001.png #{temp_mvid_name} -fps 30` # compress pngs into custom .mvid file

  if make_half_res
    puts `mvidmoviemaker -resize HALF #{temp_mvid_name} half_#{temp_mvid_name}`
    puts `rm #{temp_mvid_name}`
    puts `mv half_#{temp_mvid_name} #{temp_mvid_name}`
  end

  puts `ext_ffmpeg_splitalpha_encode_crf.sh #{temp_mvid_name} #{crf}` # convert .mvid into split mp4s

  # move the mp4 files to base directory
  dump_path = "MVID_ENCODE_CRF_#{crf}/"
  rgb_dump_path = dump_path + base_name + "_rgb_CRF_#{crf}_24BPP.m4v"
  alpha_dump_path = dump_path + base_name + "_alpha_CRF_#{crf}_24BPP.m4v"
  rgb_final_path = base_dir + base_name + "_rgb.mp4"
  alpha_final_path = base_dir + base_name + "_alpha.mp4"
  audio_final_path = base_dir + base_name + "_audio.wav"
  composition_no_audio_path = base_dir + base_name + "_no_audio.mp4"
  composition_final_path = base_dir + base_name + ".mp4"
  
  puts `cp #{rgb_dump_path} #{rgb_final_path}`
  puts `cp #{alpha_dump_path} #{alpha_final_path}`

  puts `ffmpeg -i #{base_mov_path} #{audio_final_path}`

  # compose them side-by-side
  puts `ffmpeg -i #{rgb_final_path} -vf "pad=2*iw:ih [left]; movie=#{alpha_final_path} [right]; [left][right] overlay=main_w/2:0" -b:v 768k #{composition_no_audio_path};`
  puts `ffmpeg -i #{composition_no_audio_path} -i #{audio_final_path} -c:v copy -c:a aac -strict experimental #{composition_final_path}`

  # clean up
  puts `rm -rf #{temp_path}`
end

def mplayer_installed?
  system('which mplayer > /dev/null 2>&1')
end

def animator_utils_installed?
  system('which mvidmoviemaker > /dev/null 2>&1')
end