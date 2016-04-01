if RUBY_PLATFORM == 'java'
  require "chunky_png"
else
  require 'oily_png'
end

module RSpec::PageRegression

  class ImageComparison
    include ChunkyPNG::Color

    attr_reader :result

    def initialize(filepaths, configuration)
      @filepaths = filepaths

      if configuration.passive_visual_regressor == true
        @result = compare_passive
      else
        @result = compare
      end
    end

    def expected_size
      [@iexpected.width , @iexpected.height]
    end

    def test_size
      [@itest.width , @itest.height]
    end

    private

    def compare_passive
      if @filepaths.expected_image.exist?
        @iexpected = ChunkyPNG::Image.from_file(@filepaths.expected_image)
        @itest = ChunkyPNG::Image.from_file(@filepaths.test_image)
        puts "Size difference detected." if  test_size != expected_size
        unless pixels_match?
          puts "Difference detected in expect and test image."
          puts "  File: #{@filepaths.difference_image}"
        end
      end
      create_directory_if_not_exists
      FileUtils.cp(@filepaths.test_image, @filepaths.expected_image)
      return :match
    end

    def create_directory_if_not_exists
      if Dir.exists?(@filepaths.expected_image.dirname)
        return
      else
        FileUtils.mkdir_p(@filepaths.expected_image.dirname)
      end
    end

    def compare
      @filepaths.difference_image.unlink if @filepaths.difference_image.exist?

      return :missing_expected unless @filepaths.expected_image.exist?
      return :missing_test unless @filepaths.test_image.exist?

      @iexpected = ChunkyPNG::Image.from_file(@filepaths.expected_image)
      @itest = ChunkyPNG::Image.from_file(@filepaths.test_image)

      return :size_mismatch if test_size != expected_size

      return :match if pixels_match?

      create_difference_image
      return :difference
    end

    def pixels_match?
      max_count = RSpec::PageRegression.threshold * @itest.width * @itest.height
      count = 0
      @itest.height.times do |y|
        next if @itest.row(y) == @iexpected.row(y)
        diff = @itest.row(y).zip(@iexpected.row(y)).select { |x, y| x != y }
        count += diff.count
        return false if count > max_count
      end
      return true
    end

    def create_difference_image
      idiff = ChunkyPNG::Image.from_file(@filepaths.expected_image)
      xmin = @itest.width + 1
      xmax = -1
      ymin = @itest.height + 1
      ymax = -1
      @itest.height.times do |y|
        @itest.row(y).each_with_index do |test_pixel, x|
          idiff[x,y] = if test_pixel != (expected_pixel = idiff[x,y])
                         xmin = x if x < xmin
                         xmax = x if x > xmax
                         ymin = y if y < ymin
                         ymax = y if y > ymax
                         rgb(
                           (r(test_pixel) - r(expected_pixel)).abs,
                           (g(test_pixel) - g(expected_pixel)).abs,
                           (b(test_pixel) - b(expected_pixel)).abs
                         )
                       else
                         rgb(0,0,0)
                       end
        end
      end

      idiff.rect(xmin-1,ymin-1,xmax+1,ymax+1,rgb(255,0,0))

      idiff.save @filepaths.difference_image
    end
  end
end
