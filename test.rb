require 'dotenv'
Dotenv.load

require 'rmagick'
require_relative 'lib/iiif_s3'

# Set up configuration variables
opts = {}
# opts[:image_directory_name] = "img"
# opts[:output_dir] = "/Users/sanioka/IvisSites/iiif_s3/_output"
opts[:variants] = { "reference" => 600, "access" => 1200}
opts[:upload_to_s3] = false
opts[:image_types] = [".jpg", ".tif", ".jpeg", ".tiff"]
opts[:document_file_types] = [".pdf"]

# EastView custom param
opts[:tile_width] = 256
opts[:thumbnail_size] = 400
opts[:tile_scale_factors] = [1,2,4,8]
opts[:base_url] = 'http://127.0.0.1:8887'
opts[:verbose] = true

# Setup Temporary stores
@data = []
@cleanup_list = []
@dir = "./data"


def add_image(file, is_doc = false)
  name = File.basename(file, File.extname(file))
  name_parts = name.split("_")
  is_paged = name_parts.length == 8
  page_num = is_paged ? name_parts[7].to_i : 1
  name_parts.pop if is_paged
  id = name_parts.join("_")

  obj = {
        "path" => "#{file}",
        "id"       => id,
        "label"    => name_parts.join("."),
        "is_master" => page_num == 1,
        "page_number" => page_num,
        "is_document" => false,
        "description" => "This is a test file generated as part of the development on the ruby IiifS3 Gem. <b> This should be bold.</b>"
    }

  if is_paged
    obj["section"] = "p#{page_num}"
    obj["section_label"] = "Page #{page_num}"
  end

  if is_doc
    obj["is_document"] = true
  end
  @data.push IiifS3::ImageRecord.new(obj)
end

def add_to_cleanup_list(img)
  @cleanup_list.push(img)
end

def cleanup
  @cleanup_list.each do |file|
    File.delete(file)
  end
end


iiif = IiifS3::Builder.new(opts)
iiif.create_build_directories

Dir.foreach(@dir) do |file|
  if opts[:image_types].include? File.extname(file)
    add_image("#{@dir}/#{file}")
  elsif opts[:document_file_types].include? File.extname(file)
    path = "#{@dir}/#{file}"
    images = IiifS3::Utilities::PdfSplitter.split(path)
    images.each  do |img| 
      add_image(img, true)
      add_to_cleanup_list(img)
    end
  end    
end

iiif.load(@data)
iiif.process_data
#cleanup
