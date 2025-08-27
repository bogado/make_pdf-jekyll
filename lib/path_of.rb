
def relative_path_of(base)
  base = Pathname.new(base)
  raise ArgumentError.new("#{base.to_path} is not relative.") unless base.relative?
  base
end

def path_of(base, *path_components)
  other = unless path_components.empty?
            path_components
              .map { |component| path_of(component) }
              .sum Pathname.new(".")
          else
            Pathname.new("")
          end

  base = Pathname.new(".") if base.nil?
  base = Pathname.new(File.expand_path(base)) if base.instance_of?(String)

  (base / other)
end

