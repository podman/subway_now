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


class App
  VERSION = '0.0.1'
  EMAIL = ''
  PASSWORD =''
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
    
    @agent = WWW::Mechanize.new { |obj| obj.log = Logger.new('subway.log') }
    @favs = []
    
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
      get_favorites
      
      unless @options.favorite
        @favs.each do |fav|
          puts fav[:text]
        end
        puts '----------------------------------------------------------------------------------'.bold
        print 'Enter Favorite #: '
        @options.favorite = gets 
      else
      end
      
      click_favorite(@options.favorite.to_i - 1)
      
    end
    
    def get_favorites
      home_page = @agent.get('http://subwaynow.com')

      login_form = home_page.forms.first

      login_form.User = EMAIL
      login_form.password = PASSWORD

      redirect_page = @agent.submit(login_form, login_form.buttons.first)


      fav_page = redirect_page.links.first.click

      fav_trs = fav_page.search('#HomeFaves table tr')

      fav_trs.each do |tr|
        tds = tr.search('td')
        fav = "#{tds[1].inner_text} ".red.bold

        info_td = tds[2]

        fav_link_info = info_td.search('.FaveName a').first
        fav += "#{fav_link_info.inner_text}".yellow.bold

        fav_link_href = fav_link_info.attributes['href'].value
        
        fav_link = nil
        
        fav_page.links.each do |link|
          if link.href == fav_link_href
            fav_link = link 
            break
          end
        end

        fav += "\n  Location: " + info_td.search('.VendorName').first.inner_text

        info_td.search('.FaveProducts li').each do |fave|
          fav += "\n  " + fave.inner_text
        end

        @favs.push({:text => fav, :link => fav_link})

      end

    end
    
    def click_favorite(idx)
      order_page = @favs[idx][:link].click
      data = order_page.search('.CheckoutList td')
      str = ""
      
      tab_position = 0
      
      first_summary = true
      first_total = true
      
      data.each do |d|
        if d.attributes['class'].value == 'product'
           str = "\n#{d.inner_text}".bold.red
           tab_position = d.inner_text.size
        elsif d.attributes['class'].value == 'product money'
          val = d.inner_text.match(/(\d+\.\d+)+/)[1]
          str += "\t $#{val}".green
          puts str
          str = ""
        elsif d.attributes['class'].value == 'optioncheck'
          puts "    #{d.inner_text}".green
        elsif d.attributes['class'].value == 'summary'
          if first_summary
            puts '----------------------------------------------------------------------------------'
            first_summary = false
          end
          val = "    #{d.inner_text}"
          while val.length < tab_position
            val += " "
          end 
          str = val.green.bold
        elsif d.attributes['class'].value == 'summary money'
          str += "\t #{d.inner_text}"
          puts str
          str = ""
        elsif d.attributes['class'].value == 'total'
          if first_total
            first_total = false
            puts '----------------------------------------------------------------------------------'.bold
          end
          val = "    #{d.inner_text}"
          while val.length < tab_position
            val += " "
          end 
          str = val.cyan.bold
        elsif d.attributes['class'].value == 'total money'
          str += "\t #{d.inner_text}".cyan.bold
          puts str
          str = ""
        end
      end
      
      pickup_form = order_page.form('aspnetForm')
      pickup_form.radiobuttons.first.checked = true
      
      order_form = order_page.form('frmCheckout')
      
      puts "\n"
      print "Are you sure you want to order this? [Y/n]: "
      order = gets
      
      if (order.strip == 'Y' || order.strip == 'y')
        do_order(order_form)
      end
      
    end
    
    def do_order(form)
      #page = @agent.submit(form, form.buttons.last)
      puts "\nSuccess! Check your email or SMS for confirmation of your order.".yellow.bold
    end
    
end


# TO DO - Add your Modules, Classes, etc


# Create and run the application
app = App.new(ARGV, STDIN)
app.run