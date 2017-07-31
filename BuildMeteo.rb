# Main function
if __FILE__ == $0
  require 'CSV'
  require './Estimate'

  # For local testing purpose only
  SRCE_DIR = './glib/'
  DEST_DIR = './result/'
  MAKAO_DIR = './makao/'
  se = Estimate.new(SRCE_DIR, DEST_DIR);

  # Step 0: setup the environment and generate gdf files using MAKAO
  se.prep(MAKAO_DIR)

  # First Step: Divide trace.gdf to edge_origin.gdf & node_origin.gdf
  se.divide_gdf

  # Second Step: Get files from git log
  se.get_files_from_log

  # Third Step: Output all the commit files paths to the commit_paths.txt used to test prediction result.
  file = File.open("#{DEST_DIR}/all_changed_files.txt",'r')
  file2 = File.open("#{DEST_DIR}/commit_paths.txt",'w')
  array = file.readlines
  array.each do |item|
    item.delete("\n")
    if item.start_with?('commit')
      file2.syswrite("\n")
    else
      file2.syswrite("#{SRCE_DIR}/#{item} ")
    end
  end

  # Fourth Step: Output all commit id to temp.txt
  file = File.open("#{DEST_DIR}/all_changed_files.txt",'r')
  file2 = File.open("#{DEST_DIR}/temp.txt", 'w')
  array = file.readlines;
  commit_array = Array.new
  array.each do |item|
    if item.start_with?('commit')
      temp = item.split(' ')
      commit_array.push(temp.last)
      file2.syswrite(temp.last+"\n")
    end
  end

  # Fifth Step: Predict build time for commits
  file = File.open("#{DEST_DIR}/temp.txt",'r')
  array = file.readlines
  array_output = Array.new
  loopvar = 0
  array.each do |item|
    estimated_time = se.predictTime(item, false) # Not testing the real time
    array_output.push([item,estimated_time[0],estimated_time[1]])
    loopvar += 1
    break if loopvar >= 100 # Run 30 time for now
  end
  File.open("#{DEST_DIR}/commit_predict.csv",'w'){
    |f|
    f.write(array_output.inject([]) { |csv, row|  csv <<  CSV.generate_line(row) }.join(''))
  }

  # Sixth Step: Test results
  se.get_real_time

  # The final prediction result: commit_predict.csv
  # The real time: real_time.csv

end