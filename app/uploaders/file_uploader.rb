class FileUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_allowlist
    %w[pdf doc docx xls xlsx ppt pptx txt csv zip]
  end

  def size_range
    0..10.megabytes
  end
end
