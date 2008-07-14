# Defines the Autumn::Formatting class, which provides macros for different
# protocols for IRC message stylization.

module Autumn
  
  # Adds text formatting to Autumn objects. Text formatting (color and styles)
  # is not a part of the original IRC spec, so many clients have come up with
  # many different ways of sending formatted text. The classes in this module
  # encapsulate those various methods.
  #
  # To add formatting to a stem or leaf, simply include the appropriate module
  # in your Leaf subclass, Stem instance, or other Autumn object. You can also
  # use these constants directly from the module, without adding them into your
  # class.
  #
  # Where possible, all modules in the Formatting module follow an implicit
  # protocol, which includes methods like +color+, +bold+, +plain+, and
  # +underline+.
  
  module Formatting
    
    # The mIRC format is the oldest IRC text formatting protocol, written for
    # use with the mIRC client. Although mIRC formatting is by far the most
    # common and most widely supported, it is also has the fewest features. mIRC
    # also has some limitations that can occur when coloring text; please see
    # the color method for more information.
    #
    # To stylize your text, insert the appropriate style code in your text where
    # desired. For example (assuming you have <tt>include</tt>d the Mirc
    # module):
    #
    #  "I'm feeling #{BOLD}bold today, and #{ITALIC}how#{PLAIN}!"
    #
    # yields:
    #
    # I'm feeling <b>bold today, and <i>how</i></b>!
    #
    # To colorize text, you must call the color method, and insert an UNCOLOR
    # token at the end of the colorized text:
    #
    #  "The system is: #{color(:red)}down#{UNCOLOR}!"
    
    module Mirc
      # Insert this character to set all following text unformatted.
      PLAIN = 15.chr
      # Insert this character to set all following text bolded.
      BOLD = 2.chr
      # Insert this character to set all following text italicized.
      ITALIC = 22.chr
      # Insert this character to set all following text underlined.
      UNDERLINE = 31.chr
      
      # The mIRC color code sentinel.
      COLOR_CODE = 3.chr
      # Insert this character to stop colorizing text.
      UNCOLOR = COLOR_CODE + " "
      # Same as UNCOLOR, but suppresses the trailing space for situations where
      # no conflict is assured.
      UNCOLOR_NO_SPACE = COLOR_CODE
      # Valid IRC colors, in the mIRC style, to be used with the color method.
      COLORS = {
        :white => '00',
        :black => '01',
        :dark_blue => '02',
        :navy_blue => '02',
        :dark_green => '03',
        :red => '04',
        :brown => '05',
        :dark_red => '05',
        :purple => '06',
        :dark_yellow => '07',
        :olive => '07',
        :orange => '07',
        :yellow => '08',
        :green => '09',
        :lime => '09',
        :dark_cyan => '10',
        :teal => '10',
        :cyan => '11',
        :blue => '12',
        :royal_blue => '12',
        :magenta => '13',
        :pink => '13',
        :fuchsia => '13',
        :gray => '14',
        :light_gray => '15',
        :silver => '15'
      }
      
      # Colors the following text with a foreground and background color. Colors
      # are a symbol in the COLORS hash. By default the background is left
      # uncolored. This method returns a string that should be prepended to the
      # text you want to colorize. Append an UNCOLOR token when you wish to end
      # colorization.
      #
      # Because of limitations in the mIRC color-coding system, a space will be
      # added after the color code (and before any colorized text). Without this
      # space character, it is possible that your text will appear in the wrong
      # color. (This is most likely to happen when colorizing numbers with
      # commas in them, such as "1,160".) If you would like to suppress this
      # space, because you either are sure that your text will be formatted
      # correctly anyway, or you simply don't care, you can pass
      # <tt>:suppress_space => true</tt> to this method.

      def color(fgcolor, bgcolor=nil, options={})
        fgcolor = :black unless COLORS.include? fgcolor
        bgcolor = :white unless (bgcolor.nil? or COLORS.include? bgcolor)
        "#{COLOR_CODE}#{COLORS[fgcolor]}#{bgcolor ? (',' + COLORS[bgcolor]) : ''}#{options[:suppress_space] ? '' : ' '}"
      end

      # Sets all following text unformatted.
      def plain; PLAIN; end

      # Sets all following text bold.
      def bold; BOLD; end

      # Sets all following text italic.
      def italic; ITALIC; end

      # Sets all following text underline.
      def underline; UNDERLINE; end
      
      # Removes coloring from all following text. Options:
      #
      # +suppress_space+:: By default, this method places a space after the
      #                    uncolor token to prevent "color bleed." If you would
      #                    like to suppress this behavior, set this to true.
      def uncolor(options={})
        options[:suppress_space] ? UNCOLOR_NO_SPACE : UNCOLOR
      end
    end
    
    # The default formatter for leaves that do not specify otherwise.
    DEFAULT = Mirc
    
    # The ircle formatting system is an adaptation of the mIRC system, written
    # for use by the ircle Macintosh client. Its primary purpose is to improve
    # upon mIRC's lackluster color support. The ircle protocol is identical to
    # the mIRC protocol for purposes of text styling (bold, italic, underline),
    # so stylized text will appear the same on both clients.
    #
    # The only difference is in text colorization, for which ircle has a
    # slightly better system, but one that is incompatible with mIRC-type
    # clients.
    #
    # Styling text is done exactly as it is in the Mirc module; coloring text is
    # done with the COLORS hash, as so:
    #
    #  "The system is: #{COLORS[:red]}down#{PLAIN}!"
    #
    # Note that there is no support for background coloring.
    
    module Ircle
      # Insert this character to set all following text unformatted and
      # uncolored.
      PLAIN = 15.chr
      # Insert this character to set all following text bolded.
      BOLD = 2.chr
      # Insert this character to set all following text italicized.
      ITALIC = 22.chr
      # Insert this character to set all following text underlined.
      UNDERLINE = 31.chr
      # The ircle color code sentinel.
      COLOR_CODE = 3.chr
      # Insert a character from this hash to set the color of all following
      # text.
      COLORS = {
        :white => COLOR_CODE + '0',
        :black => COLOR_CODE + '1',
        :red => COLOR_CODE + '2',
        :orange => COLOR_CODE + '3',
        :yellow => COLOR_CODE + '4',
        :light_green => COLOR_CODE + '5',
        :green => COLOR_CODE + '6',
        :blue_green => COLOR_CODE + '7',
        :cyan => COLOR_CODE + '8',
        :light_blue => COLOR_CODE + '9',
        :blue => COLOR_CODE + ':',
        :purple => COLOR_CODE + ';',
        :magenta => COLOR_CODE + '<',
        :purple_red => COLOR_CODE + '=',
        :light_gray => COLOR_CODE + '>',
        :dark_gray => COLOR_CODE + '?',
        :dark_red => COLOR_CODE + '@',
        :dark_orange => COLOR_CODE + 'A',
        :dark_yellow => COLOR_CODE + 'B',
        :dark_light_green => COLOR_CODE + 'C',
        :dark_green => COLOR_CODE + 'D',
        :dark_blue_green => COLOR_CODE + 'E',
        :dark_cyan => COLOR_CODE + 'F',
        :dark_light_blue => COLOR_CODE + 'G',
        :dark_blue => COLOR_CODE + 'H',
        :dark_purple => COLOR_CODE + 'I',
        :dark_magenta => COLOR_CODE + 'J',
        :dark_purple_red => COLOR_CODE + 'K',
        # User-defined colors:
        :server_message => COLOR_CODE + 'a',
        :standard_message => COLOR_CODE + 'b',
        :private_message => COLOR_CODE + 'c',
        :notify => COLOR_CODE + 'd',
        :dcc_ctcp => COLOR_CODE + 'e',
        :window_bg => COLOR_CODE + 'f',
        :own_message => COLOR_CODE + 'g',
        :notice => COLOR_CODE + 'h',
        :user_highlight => COLOR_CODE + 'i',
        :userlist_chanop => COLOR_CODE + 'l',
        :userlist_ircop => COLOR_CODE + 'm',
        :userlist_voice => COLOR_CODE + 'n'
      }
      # For purposes of cross-compatibility, this constant has been added to
      # match the Mirc module. Removes all formatting and coloring on all
      # following text.
      UNCOLOR = PLAIN
      
      # For purposes of cross-compatibility, this method has been added to match
      # the Mirc method with the same name. All inapplicable parameters and
      # color names are ignored.
      
      def color(fgcolor, bgcolor=nil, options={})
        COLORS[fgcolor]
      end

      # Sets all following text unformatted.
      def plain; PLAIN; end

      # Sets all following text bold.
      def bold; BOLD; end

      # Sets all following text italic.
      def italic; ITALIC; end

      # Sets all following text underline.
      def underline; UNDERLINE; end
    end
  end
end
