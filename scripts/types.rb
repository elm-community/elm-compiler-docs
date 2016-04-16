 #!/usr/bin/env ruby

# This script parses the types declared in the Elm compiler into a Markdown
# table. It expects the path to elm-compiler as a command-line argument and
# writes to stdout.

def usage
  puts "usage: pass elm-compiler path on command line"
  exit 1
end

return usage if ARGV[0].nil?
/Version: (.*)/.match IO.read(File.join(ARGV[0], "elm-compiler.cabal"))
VERSION = $1
return usage if VERSION.nil?
SRC = File.join(ARGV[0], "src")
return usage unless File.directory?(SRC)


entries = []
Entry = Struct.new("Entry", :name, :module, :line_start, :line_end, :definition) do
  def render
    ["#{self[:name]}", definition, module_name].join(" | ")
  end

  def definition
    self[:definition].map{|line| "`#{line}`"}.join("<br/>")
  end

  def module_name
    mod = self[:module]
    l1 = self[:line_start]
    l2 = self[:line_end]
    "[#{mod}](https://github.com/elm-lang/elm-compiler/blob/#{VERSION}/src/#{mod.gsub(".", "/")}.hs#L#{l1}-L#{l2})"
  end
end

Dir.chdir SRC do
  Dir.glob(File.join("**", "*.hs")).each do |filename|
    current_module = ""
    current_entry = nil
    IO.readlines(filename).each_with_index do |line, i|
      case line
      when /^module ([A-Za-z.]*)/
        current_module = $1
      when /^((new)?type|data) ([A-Za-z']*)/
        entries << current_entry unless current_entry.nil?
        current_entry = Entry.new($3, current_module, i+1, 0, [line.rstrip])
      when /^\s*$/
        unless current_entry.nil?
          entries << current_entry
          current_entry = nil
        end
      else
        unless current_entry.nil?
          current_entry[:definition] << line.rstrip
          current_entry[:line_end] = i+1
        end
      end
    end
  end
end

# Remove this line to get a by-module listing
entries = entries.sort_by{|entry| entry[:name]}

puts <<EOF
# Type Glossary

This is a procedurally generated list of all types defined by the #{VERSION} Elm compiler.

For those unfamiliar with Haskell,
* `data` is equivalent to Elm's `type`
* `type` is equivalent to `type alias`
* `newType` is like `type` except there's only one tag, and so it disappears at runtime.

Name | Definition | Defined (link)
-----|------------|---------------
EOF

entries.each{|entry| puts entry.render}
