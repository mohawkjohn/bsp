require "packable"
require "pry"

class Segment
  TYPES = [nil, :modified_difference_arrays, :chebyshev_position, :chebyshev_position_velocity,
           :type_4, :discrete_states, :type_6, :type_7, :lagrange_equal, :lagrange_unequal, :space_command_two_line,
           :type_11, :hermite_equal, :hermite_unequal, :chebyshev_unequal, :precessing_conic,
           :type_16, :equinoctial, :hermite_lagrange, :piecewise, :chebyshev_velocity, :extended_modified_difference_arrays]

  NAIF = {0 => :ss_bc, 1 => :mercury_bc, 2 => :venus_bc, 3 => :earth_moon_bc, 4 => :mars_bc, 5 => :jupiter_bc,
          6 => :saturn_bc, 7 => :uranus_bc, 8 => :neptune_bc, 9 => :pluto_bc, 10 => :sun, 199 => :mercury,
          299 => :venus, 399 => :earth, 301 => :moon, 499 => :mars, 401 => :phobos, 402 => :deimos,
          599 => :jupiter, 501 => :io, 502 => :europa, 503 => :ganymede, 504 => :callisto, 505 => :amalthea,
          506 => :himalia, 507 => :elara, 699 => :saturn, 799 => :uranus, 899 => :neptune, 999 => :pluto,
          901 => :charon, 2000001 => :ceres, 2025143 => :itokawa}

  FRAMES = {1 => :j2000, 2 => :b1950, 3 => :fk4, 13 => :galactic, 14 => :de200, 15 => :de202, 16 => :marsiau,
            17 => :eclipj2000, 18 => :eclipb1950, 19 => :de140, 20 => :de142, 21 => :de143}

  def initialize name, summary_record, f, endian: :little
    @name          = name
    @interval      = [summary_record[0], summary_record[1]]
    @naif_target   = NAIF[summary_record[2]]
    @naif_center   = NAIF[summary_record[3]]
    @naif_frame    = FRAMES[summary_record[4]]
    @type          = TYPES[summary_record[5]]
    @initial       = summary_record[6] * 8 - 8
    @final         = summary_record[7] * 8
    @skip          = @initial % 1024

    if @type == :chebyshev_position
      f.seek(@final - 32)

      # INIT is the initial epoch of the first record, given in ephemeris seconds past J2000. 
      #@initial_epoch =
      f.read([Float, precision: :double, bytes: 8, endian: endian])

      # INTLEN is the length of the interval covered by each record, in seconds.
      @interval_length = f.read([Float, precision: :double, bytes: 8, endian: endian])

      # RSIZE is the total size of (number of array elements in) each record.
      @record_size   = f.read([Float, precision: :double, bytes: 8, endian: endian]).to_i

      # N is the number of records contained in the segment. 
      @num_records   = f.read([Float, precision: :double, bytes: 8, endian: endian]).to_i

      @records = []
      f.seek(@initial) # skip midpoint and radius
      @num_records.times do
        num_components = (@record_size-2) / 3
        raise(IOError, "record_size should equal components times three plus two") unless num_components*3 + 2 == @record_size

        @records << {
          midpoint: f.read([Float, precision: :double, bytes: 8, endian: endian]),
          radius:   f.read([Float, precision: :double, bytes: 8, endian: endian]),
          x: StringIO.new(f.read(8*num_components)).to_enum(:each, [Float, precision: :double, bytes: 8, endian: endian]).to_a,
          y: StringIO.new(f.read(8*num_components)).to_enum(:each, [Float, precision: :double, bytes: 8, endian: endian]).to_a,
          z: StringIO.new(f.read(8*num_components)).to_enum(:each, [Float, precision: :double, bytes: 8, endian: endian]).to_a
        }
      end
    else
      raise(NotImplementedError, "sorry, only able to handle DE430 right now")
    end
  end

  attr_reader :interval, :naif_target, :naif_center, :naif_frame, :type, :initial, :final, :records
end

class Bsp
  def read_comments
    comments = [@file.gets("\x04", 1000)] #.split("\x00").join("\n")
    while comments.last.size == 1000 && comments.last[-1] != "\x04"
      @file.gets(24) # ignore 24 characters
      comments << @file.gets("\x04", 1000)
    end

    # Skip to the end of this comment block. 0x04 just indicates it's the last one, not that
    # it's immediately ending.
    @file.seek(1000 - comments.last.size, IO::SEEK_CUR)
    comments.last.chomp!("\x04")

    # Now put the separate comments together.
    comments.join().split("\x00").join("\n")
  end


  # These give the time intervals for each block, I think? Not sure what the integers are.
  def read_summary_records
    ary = []
    next_number = @header[:fward]

    while next_number >= 0
      @file.seek(next_number * 1024)
      
      next_number,
      prev_number,
      num_summaries = @file >>
                      [Float, precision: :double, endian: endian] >>
                      [Float, precision: :double, endian: endian] >>
                      [Float, precision: :double, endian: endian]
      next_number = next_number.to_i - 1
      prev_number = prev_number.to_i - 1
      num_summaries = num_summaries.to_i

      num_summaries.times do
        ary << []
        @header[:nd].times do |d|
          ary.last << @file.read([Float, precision: :double, endian: endian])
        end
        @header[:ni].times do |i|
          ary.last << @file.read([Integer, bytes: 4, endian: endian])
        end

        # If we have an odd number of integers, need to read to the end of the word
        if @header[:ni] % 2 == 1
          @file.seek(4, IO::SEEK_CUR)
        end
      end
    end

    ary
  end

  def read_name_records count
    @file.seek((@header[:bward]+1) * 1024)
    num_characters = 8 * (@header[:nd] + (@header[:ni] + 1) / 2)
    ary = []
    count.times do
      ary << @file.read(num_characters)
    end
    ary
  end

  def read_element_record
    @file.seek((@header[:bward]+2) * 1024)
    ary = []
    128.times do
      ary << @file.read([Float, precision: :double, endian: endian])
    end
    ary
  end

  def initialize filename, endian: :native
    @file  = File.open(filename, "rb")

    @header = {}

    @header[:locidw] = @file >> [String, bytes: 8]
    @header[:locidw] = @header[:locidw].first
    if @header[:locidw][0..6] != "DAF/SPK"
      raise(IOError, "expected a DAF/SPK file, got #{@header[:locidw]}")
    else
      @header[:locidw] = @header[:locidw][0..6] # truncate the null
    end

    # http://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/req/daf.html
    @header[:nd], # The number of double precision components in each array summary.
    @header[:ni], # The number of integer components in each array summary.
    @header[:locifn], # The internal name or description of the array file. 
    @header[:fward], # The record number of the initial summary record in the file.
    @header[:bward], # The record number of the final summary record in the file.
    @header[:free], # The first free address in the file. This is the address at which the first element of the next array to be added to the file will be stored.
    @header[:locfmt], # The character string that indicates the numeric binary format of the DAF. The string has value either "LTL-IEEE" or "BIG-IEEE."
    @header[:prenul], # A block of nulls to pad between the last character of LOCFMT and the first character of FTPSTR to keep FTPSTR at character 700 (address 699) in a 1024 byte record.
    @header[:ftpstr], # The FTP validation string.
    @header[:pstnul] = # A block of nulls to pad from the last character of FTPSTR to the end of the file record. Note: this value enforces the length of the file record as 1024 bytes. 
    @file >> [Integer, signed: false, endian: :little] >> [Integer, signed: false, endian: :little] >>
             [String, bytes: 60] >>
             [Integer, signed: false, endian: :little] >> [Integer, signed: false, endian: :little] >>
             [Integer, signed: false, endian: :little] >>
             [String, bytes: 8] >> [String, bytes: 603] >>
             [String, bytes: 28] >>
             [String, bytes: 297]

    # Switch from FORTRAN to C-based array counts
    @header[:fward] = @header[:fward]-1
    @header[:bward] = @header[:bward]-1
    
    @endian = @header[:locfmt] == "LTL-IEEE" ? :little : :big
    if @endian != endian
      raise(IOError, "file appears to be a different endian than you specified")
    end
    
    # TODO: Check ftpstr to make sure FTP download didn't happen in ASCII mode.
    
    @header.delete(:pstnul)
    @header.delete(:prenul)

    # Now, file position should be 1024.
    
    # Comment area
    # http://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/req/spc.html
    @comments = read_comments

    summary_records = read_summary_records
    name_records    = read_name_records(summary_records.size)
    @segments       = summary_records.map.with_index { |rec,i| Segment.new(name_records[i], rec, @file, endian: endian) }
  end


  attr_reader :header, :endian, :segments
  
end

require_relative 'bsp/version.rb'
