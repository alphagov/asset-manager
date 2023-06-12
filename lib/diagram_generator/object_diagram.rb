module DiagramGenerator
  class ObjectDiagram
    def initialize(model_class, model_id)
      @model_class = model_class
      @model_id = model_id
      @emitted_objects = []
    end

    def draw
      # suppress sql
      # old_log_level = ::ActiveRecord::Base.logger.level
      # ::ActiveRecord::Base.logger.level = Logger::INFO

      puts "-" * 60

      puts "@startuml"
      puts "node AssetManager {"
      model_underscored = @model_class.underscore

      assets = Asset.unscoped.all.filter {|asset| asset.legacy_url_path =~ /\/system\/uploads\/#{model_underscored}\/[^\/]+\/#{@model_id}\// }

      assets.each do |asset|
        emit_object(asset, %i[state draft redirect_url content_type deleted_at file legacy_url_path])
      end

      puts "}"
      puts "@enduml"

      puts "-" * 60

      # ::ActiveRecord::Base.logger.level = old_log_level
    end

    private

    def emit_object(obj, fields)
      key = object_key(obj)
      unless @emitted_objects.include? key
        @emitted_objects << key
        puts "object \"#{object_name(obj)}\" as #{object_key(obj)} {"
        fields.each do |f|
          if obj[f].is_a? Time
            puts "  #{f}: #{obj[f].to_fs(:short)}"
          else
            puts "  #{f}: #{obj[f]}"
          end
        end
        puts "}"
      end
    end

    def object_key(obj)
      "am_#{obj.class.name}_#{obj._id}"
    end

    def object_name(obj)
      "#{obj.class.name}:#{obj._id}"
    end

  end
end
