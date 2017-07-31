# Written by Qi Cao and Ray Wen in Montreal, Canada
class Estimate
  require 'shellwords'

  # Only allow trace.gdf to be the input file
  def initialize(path_in,path_out)
    begin
      @trace_path = path_in + 'trace.gdf';
      @path_in = path_in;
      @path_out = path_out;
      @edge_file_origin = File.new(File.join(@path_out,'edge_origin.gdf'),'w+')
      @node_file_origin = File.new(File.join(@path_out,'node_origin.gdf'),'w+')
      @time_sum = 0;
      @array_node = File.readlines(@node_file_origin)
      @array_edge = File.readlines(@edge_file_origin)

      @name_changed = Array.new
    rescue Exception => e
      puts 'Please check your file paths! Aborting...'
      puts e.message
      puts e.backtrace.inspect
    end
  end

  # Search node from the nodedef part of trace.gdf, return the name of the node.
  # Return local name of changed node
  def search_node(node_changed)
    if node_changed.is_a?Array
      @node_changed = node_changed
    else
      @node_changed = node_changed.split(',')
    end

    @array_node.each do |item|
      node_array = item.split(',')
      @node_changed.each do |node|
        if node_array[2].end_with?(node)
          @name_changed.push(node_array[0])
          @time_sum += time_convert(node_array[3])
        end
      end
    end
    return @name_changed
  end

  # Search all edges from the edgedef part of trace.gdf
  # Return the predicted total time of all edges
  def search_all_edge
    @name_viewed = Array.new
    search_edge()
    addNode()
    return @time_sum
  end

  def search_edge()
    temp = Array.new
    @array_edge.each do |item|
      edge_array = item.split(',')
      @name_changed.each do |name|
        if edge_array[1].eql?(name)
          @edge_file.syswrite(item)
          if !temp.include?(edge_array[0]) && !@name_changed.include?(edge_array[0]) && !@name_viewed.include?(edge_array[0])
            temp.push(edge_array[0])
          end
        end
      end
    end
    @name_changed.each do |name|
      @name_viewed.push(name)
    end
    @name_changed.clear
    @name_changed = temp
    if (@name_changed.empty?)
      return
    else
      search_edge()
    end
  end

  def addNode()
    @array_node.each do |item|
      @name_viewed.each do |name|
        node_array = item.split(',')
        if node_array[0].eql?(name)
          if(!node_array[3].equal?('[]'))
            @time_sum = @time_sum + time_convert(node_array[3])
          end
          @node_file.syswrite(item);
        end
      end
    end
  end

  # Converts a string of time with the format of [xx:xx:xx] to a float
  def time_convert(time_string)
    time_string.delete!('[')
    time_string.delete!(']')
    time_float = 0
    if(time_string.include?(';'))
      time_array = time_string.split(';')
      time_array.each do |time|
        if(time.include?(':'))
          each_time_array = time.split(':')
          time_float = time_float + each_time_array[0].to_f*60+each_time_array[1].to_f
        else
          time_float = time_float + time.to_f;
        end
      end
    else
      if(time_string.include?(':'))
        each_time_array = time_string.split(':')

        time_float = time_float + each_time_array[0].to_f*60+each_time_array[1].to_f
      else
        time_float = time_string.to_f
      end
    end
    return time_float
  end

  # Get real time from out.txt
  def get_real_time
    real_time = File.open(File.join(@path_out,'out_commit.txt'),'r')
    real_time_out = File.open(File.join(@path_out,'real_time.csv'),'w')
    array_read = real_time.readlines
    array_read.each do |item|
      if(item.include?('CPU'))
        times = item.split(' ')
        times[2].delete!('elapsed')
        time = time_convert(times[2])
        real_time_out.syswrite(time.to_s+"\n")
      end
    end

  end

  # Divide trace.gdf to node_origin.gdf & edge_origin.gdf to save loop time
  def divide_gdf
    cmd = "sed '/edge/,$d' #{@path_in}trace.gdf>#{@path_out}temp.gdf;
        sed '0,/edge/d' #{@path_in}trace.gdf>#{@path_out}edge_origin.gdf"
    bash(cmd)
    temp_file = File.open(File.join(@path_out,'temp.gdf'),'w+')
    node_file_origin =File.new(File.join(@path_out,'node_origin.gdf'),'w+')
    temp = temp_file.readlines
    temp.each do |item|
      node_array = item.split(',')
      node_file_origin.syswrite(node_array[0].to_s+','+node_array[1].to_s+','+node_array[9].to_s+'/'+
        node_array[10].to_s+','+node_array[17].to_s)
    end
    cmd2 = "rm #{@path_out}/temp.gdf"
    bash(cmd2)
  end

  def get_files_from_log
    bash("echo $0")
    cmd = "cd #{@path_in}; git log --name-only >| result.txt"
    bash(cmd)
    log_file = File.open(File.join(@path_in,'result.txt'),'r+')
    change_files = File.new(File.join(@path_out,'all_changed_files.txt'),'w');
    array = log_file.readlines
    array.each do |item|
      if(!item.start_with?('Author') && !item.start_with?('Date') && !item.start_with?(' ') && item != "\n")
        change_files.syswrite(item);
      end
    end
    # cmd = "cd #{@path_in}; git log --name-only --oneline | grep -v '^.\{7\}\s' > #{@path_out}all_changed_files.txt"
  end

  def bash(command)
    escaped_command = Shellwords.escape(command);
    system "bash -c #{escaped_command}"
  end

  def reconfigure(commit_id)
    cmd = "
          export LIBFFI_CFLAGS=-I/usr/include/ffi
          export LIBFFI_LIBS=-lffi
          export MAKAO='/Users/ray/Desktop/makao'
          cd #{@path_in};
          git checkout -b #{commit_id[0,7]} #{commit_id};
          source ~/.bash_profile;
          make distclean;
          ./autogen.sh;
          # ./autogen.sh &> output_autogen.txt;
          tar -xvf deps.tar;
          $MAKAO/parsing/bin/makewrapper.sh all 2&> temp.txt;
          gsed '/-dependencies/,+31'd temp.txt > trace.txt;
          rm temp.txt;
          $MAKAO/parsing/bin/generate_makao_graph.pl -in trace.txt -out trace.gdf -format gdf;
          # $MAKAO/parsing/bin/generate_makao_graph.pl -in trace.txt -out trace.gdf -format gdf &> output_generate_makao_graph.txt;
          "
    bash(cmd)
    divide_gdf
  end

  def predictTime(commit_id, real_make)
    commit_id.delete! "\n"
    build_file = File.open(File.join(@path_in,'build_files.txt'),'r')
    array_build = build_file.readlines()
    file = File.open(File.join(@path_out,'all_changed_files.txt'),'r')
    array = file.readlines
    array_changed_files = Array.new
    result = ''
    id = 0
    id2= 0
    array.each do |item| # Each line in all_changed_files.txt
      item.delete!("\n")
      if(item.end_with?commit_id)
        id = array.index(item)
      end
      if(id!=0 && id2 ==0 && !item.start_with?('commit'))
        array_changed_files.push(@path_in+item)
      end
      if(id!=0 && item.start_with?('commit') && array.index(item)>id)
        id2=array.index(item)
        break
      end
    end
    se = EstimateBuildingTime.new(@path_in,@path_out)
    se.search_node(array_changed_files)
    # ---------- ESTIMATE BASED ON PREVIOUS TIME: 10 sec for 'empty loop' -----------
    all_time = se.search_all_edge + 10
    array_changed_files.each do |item|
      temp_array = item.split('/')
      if array_build.include?temp_array.last+"\r\n"
        result = 'The build files have changed, the prediction may not be accurate'
        puts result
        reconfigure(commit_id)
        break
      end
    end

    # touch files to test
    test(array_changed_files.join(' ')) if real_make
    puts all_time
    return all_time, result

  end

  # Test prediction result of each commit.
  def test(path)
    cmd = "cd #{@path_in}
    echo #{path} >>#{@path_out}out_commit2.txt
    touch -c #{path}
    gtime make 2>>#{@path_out}out_commit.txt"
    bash(cmd)
  end

  # Prepares for running MAKAO in the bash environment
  def prep(makao_path)
    cmd = "
    cd #{@path_in}
    export LIBFFI_CFLAGS=-I/usr/include/ffi
    export LIBFFI_LIBS=-lffi
    export MAKAO=#{makao_path} 
    ./autogen.sh
    $MAKAO/parsing/bin/makewrapper.sh all 2&> trace.txt 
    $MAKAO/parsing/bin/generate_makao_graph.pl -in trace.txt -out trace.gdf -format gdf
    "
    bash(cmd)
  end  

end # End class
