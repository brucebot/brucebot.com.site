require 'exifr'
require 'RMagick'
require 'date'
include Magick


include FileUtils

$image_extensions = [".png", ".jpg", ".jpeg", ".gif"]

module Jekyll
  class GalleryFile < StaticFile
    def write(dest)
      return false
    end
  end

  class GalleryIndex < Page
    def initialize(site, base, dir, galleries)
      @site = site
      @base = base
      @dir = dir
      @name = "index.html"

      self.process(@name)
      self.read_yaml(File.join(base, "_layouts"), "gallery_index.html")
      self.data["title"] = "我的相册"
      self.data["galleries"] = []
      begin
        galleries.sort! {|a,b| b.data["date_time"] <=> a.data["date_time"]}
      rescue Exception => e
        puts e
      end
      galleries.each {|gallery| self.data["galleries"].push(gallery.data)}
    end
  end

  class GalleryPage < Page
    def initialize(site, base, dir, gallery_name)
      @site = site
      @base = base
      @dir = dir
      @name = "index.html"
      @images = []
      @image_info = []
      @amount = 0
      @image_exif_date= ""

      best_image = nil
      max_size = 300
      self.process(@name)
      self.read_yaml(File.join(base, "_layouts"), "gallery_page.html")
      self.data["gallery_path"] = gallery_name
      self.data["gallery"] = gallery_name.gsub(/\s/, '-')
      gallery_title_prefix = site.config["gallery_title_prefix"] || "Gallery: "
      gallery_name = gallery_name.gsub("_", " ").gsub(/\w+/) {|word| word.capitalize}
      self.data["name"] = gallery_name
      self.data["title"] = "#{gallery_title_prefix}#{gallery_name}"
      thumbs_dir = "#{site.dest}/#{dir}/thumbs"
      
      FileUtils.mkdir_p(thumbs_dir, :mode => 0755)
      Dir.foreach(dir) do |image|
        if image.chars.first != "." and image.downcase().end_with?(*$image_extensions)
          @images.push(image) 
          best_image = image
          @site.static_files << GalleryFile.new(site, base, "#{dir}/thumbs/", image)
          if File.file?("#{thumbs_dir}/#{image}") == false or File.mtime("#{dir}/#{image}") > File.mtime("#{thumbs_dir}/#{image}")
            begin
              m_image = ImageList.new("#{dir}/#{image}")
              m_image.resize_to_fit!(max_size, max_size)
              puts "Writing thumbnail to #{thumbs_dir}/#{image}"
              m_image.write("#{thumbs_dir}/#{image}")
            rescue
              puts "error"
              puts $!
            end
          end
          begin
            image_exif=EXIFR::JPEG::new("#{dir}/#{image}")
            if image_exif.date_time_original.nil?
              image_exif_date= ""
            else
              image_exif_date= image_exif.date_time_original.strftime('%Y-%m-%d')
            end
            #simage_info= "时间:"+image_exif.date_time.strftime('%Y-%m-%d')+ " 相机:"+ image_exif.model+ " 快门:"+ image_exif.exposure_time.to_s+ " 焦距:" + image_exif.focal_length.to_f.to_s + "mm 光圈:F" + image_exif.f_number.to_f.to_s+ " ISO:" + image_exif.iso_speed_ratings.to_s
            simage_info= "时间:"+image_exif_date + " 相机:"+ image_exif.model+ " 快门:"+ image_exif.exposure_time.to_s+ " 焦距:" + image_exif.focal_length.to_f.to_s + "mm 光圈:F" + image_exif.f_number.to_f.to_s+ " ISO:" + image_exif.iso_speed_ratings.to_s
            @image_info.push(simage_info)
          end

      end      
      end      
      self.data["images"] = @images
      begin
        best_image = site.config["galleries"][self.data["gallery_path"]]["best_image"]
      rescue
      end
      self.data["best_image"] = best_image
      self.data["image_info"] = @image_info
      self.data["amount"] = @images.count-1
      begin
        self.data["date_time"] = EXIFR::JPEG.new("#{dir}/#{best_image}").date_time.to_i
      rescue
      end

    end
  end

  class GalleryGenerator < Generator
    safe true

    def generate(site)
      unless site.layouts.key? "gallery_index"
        return
      end
      dir = site.config["gallery_dir"] || "photos"
      galleries = []
      begin
        Dir.foreach(dir) do |gallery_dir|
          gallery_path = File.join(dir, gallery_dir)
          if File.directory?(gallery_path) and gallery_dir.chars.first != "."
            gallery = GalleryPage.new(site, site.source, gallery_path, gallery_dir)
            gallery.render(site.layouts, site.site_payload)
            gallery.write(site.dest)
            site.pages << gallery
            galleries << gallery
          end
        end
      rescue
        puts $!
      end

      gallery_index = GalleryIndex.new(site, site.source, dir, galleries)
      gallery_index.render(site.layouts, site.site_payload)
      gallery_index.write(site.dest)
      site.pages << gallery_index
    end
  end
end