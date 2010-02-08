#!/usr/bin/env ruby 

# == Synopsis 
#   This is a simple application for ordering food from subwaynow.com
#
# == Examples
#   This command lists all of your favorites and allows you to order
#     subway_now
#
#   Other examples:
#     subway_now -f 1
#
# == Usage 
#   subway_now [options]
#
#   For help use: subway_now -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -V, --verbose       Verbose output
#   -f, --favorite      Automatically picks the given favorite and starts the ordering process
#   TO DO - add additional options
#
# == Author
#   Adam Podolnick
#
# == Copyright
#   Copyright (c) 2010 Adam Podolnick. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php

require 'rubygems'
require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'
require 'mechanize'
require 'text/highlight'
require 'logger'
require 'yaml'
require 'subway'



class App
  VERSION = '0.0.1'
    
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
    
    config = YAML::load(open('.subwayrc').read)
        
    @subway = Subway.new(config["email"], config["password"])
    
    hl = Text::ANSIHighlighter.new
    String.highlighter = hl
    
  end

  # Parse options, check arguments, then process the command
  def run
        
    if parsed_options? && arguments_valid? 
      
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      process_arguments            
      process_command
      
      puts "\nFinished at #{DateTime.now}" if @options.verbose
      
    else
      output_usage
    end
      
  end
  
  protected
  
    def parsed_options?
      
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')    { output_version ; exit 0 }
      opts.on('-h', '--help')       { output_help }
      opts.on('-V', '--verbose')    { @options.verbose = true }  
      opts.on('-q', '--quiet')      { @options.quiet = true }
      opts.on('-f', '--favorite [FAV]')   { |fav| @options.favorite = fav}
      
      opts.parse!(@arguments) rescue return false

      process_options
      true      
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "  #{name} = #{val}"
      end
    end

    # True if required arguments were provided
    def arguments_valid?
      true
    end
    
    # Setup the arguments
    def process_arguments
      # TO DO - place in local vars, etc
    end
    
    def output_help
      output_version
      RDoc::usage() #exits app
    end
    
    def output_usage
      RDoc::usage('usage') # gets usage from comments above
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    def process_command
      
      unless @options.favorite
        output_favorites
        puts '----------------------------------------------------------------------------------'.bold
        print 'Enter Favorite #: '
        @options.favorite = gets 
      else
      end
      
      click_favorite(@options.favorite.to_i - 1)
      
    end
    
    def output_favorites
      @subway.favorites.each do |favorite|
        str = "#{favorite[:id]} ".red.bold
        str += "#{favorite[:desc]}".yellow.bold
        str += "\n  Location: #{favorite[:location]}"

        favorite[:products].each do |product|
          str += "\n  #{product}"
        end
        puts str
      end
    end
    
    def click_favorite(idx)
      data = @subway.begin_order_favorite(idx)
      str = ""
      
      tab_position = 0
      
      first_summary = true
      first_total = true
      
      data.each do |d|
        case d[:type]
          when :product
            str = "\n#{d[:value]}".bold.red
            tab_position = d[:value].size
          when :product_money
            str += "\t $#{d[:value]}".green
            puts str
            str = ""
          when :option
            puts "    #{d[:value]}".green
          when :summary
            if first_summary
              puts '----------------------------------------------------------------------------------'
              first_summary = false
            end
            val = "    #{d[:value]}"
            while val.length < tab_position
              val += " "
            end 
            str = val.green.bold
          when :summary_money
            str += "\t #{d[:value]}"
            puts str
            str = ""
          when :total
            if first_total
              first_total = false
              puts '----------------------------------------------------------------------------------'.bold
            end
            val = "    #{d[:value]}"
            while val.length < tab_position
              val += " "
            end 
            str = val.cyan.bold
          when :total_money
            str += "\t #{d[:value]}".cyan.bold
            puts str
            str = ""
        end
      end
      
      puts "\n"
      print "Are you sure you want to order this? [Y/n]: "
      order = gets
      
      result = false
      
      if (order.strip == 'Y' || order.strip == 'y')
        result = @subway.complete_order
      end
      
      if result
        puts "\nSuccess! Check your email or SMS for confirmation of your order.".yellow.bold
      else
        puts "\nOh no! There was an error.".red.bold
      end
      
    end
    
end


# TO DO - Add your Modules, Classes, etc


# Create and run the application
app = App.new(ARGV, STDIN)
app.run