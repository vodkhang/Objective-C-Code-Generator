#!/usr/bin/env ruby -w
 
begin; require 'rubygems'; rescue LoadError; end
require 'appscript'; include Appscript
 
#==============================================================
# Preferences
#==============================================================
SLEEP_TIME = 0.1
Xcode = app('/Developer/Applications/Xcode.app')
@use_nonatomic = true
@position_prop_after_closing_bracket = false
@outlet = true
 
@copy = ['NSString', 'NSMutableString', 'NSArray', 'NSNumber']
@assign = ['int', 'integer', 'BOOL', 'float', 'NSUInteger', 'NSInteger', 'SEL']
@retain = []
 
#==============================================================
# Methods
#==============================================================
def find_doc_with_save(file_path)
 docs = Xcode.text_documents.get
 docs.each do |doc|
   path = doc.get.file_name.get
   if file_path == path
     doc.save
     return doc
   end
 end
 return false
end
 
def replace_contents_leopard(file_path, new_contents)
 Xcode.open(file_path)
 sleep SLEEP_TIME
 if doc = find_doc_with_save(file_path)
   doc.contents.set(new_contents)
   return true
 end
 return false
end
 
def memory_management(label)
 return " copy" if @copy.include?(label)
 return "assign" if @assign.include?(label)
 return "retain"
end
 
def use_nonatomic
 return @use_nonatomic ? "nonatomic, " : ''
end
 
#==============================================================
# Checking for .m file existence
#==============================================================
# Save the current document Snow Leopard
 
Xcode.text_documents[1].save
 
path = "%%%{PBXFilePath}%%%"
doc = find_doc_with_save(path)
 
# Continue only if we are starting in the .h file
if File.extname(path) != '.h'
 print "This is not a header file"
 exit
end
 
parent = File.dirname(path)
file_name = File.basename(path, '.*')
mPath = parent + '/' + file_name + '.m'
 
# you could check for .mm ext here also
if !File.exists?(mPath)
 print "File does not exist: #{path}"
 exit
end
 
 
#==============================================================
# Converting selection to @property, @synthensize and dealloc
#==============================================================
# copy/retain/assign
 
properties = ''
synthesize = ''
release = ''
unload = ''
 
selection = STDIN.read
if selection == ''
 find_doc_with_save(path)
 exit
end
 
selection.each do |line|
 line = line.scan("*") == [] ? line.strip : line.gsub!(/\*/, '').strip
 words = line.split(/\s+/)
 label = words.size > 2 ? words[1] : words[0]
 variable = words[-1]
 mem_label = memory_management(label)
 star = mem_label == 'assign' ? '' : '*'
 
 @outlet = false
 if label[0, 2].downcase == 'ui'
   @outlet = true
 end
 
 properties << "@property (#{use_nonatomic}#{mem_label}) #{("IBOutlet " if @outlet)}#{label} #{star}#{variable}\n"
 synthesize << "@synthesize #{variable}\n"
 release << "\t[#{variable.chop} release];\n" unless mem_label == 'assign'
 unload << "\tself.#{variable.chop} = nil;\n"
end
 
 
#==============================================================
# Reading and updating the .m file contents
#==============================================================
mFileContents = IO.read(mPath)
updatedFileContents = ''
mFileContents.split("\n").each do |line|
 if line =~ /^@implementation/
   updatedFileContents << line + "\n" + synthesize.chomp
 elsif line =~ /\[super dealloc\]/
   updatedFileContents << release.chomp + "\n" + line
 elsif line =~ /\(void\)\s?viewDidUnload/
   updatedFileContents << line + "\n" + unload.chomp
 else
   updatedFileContents << line
 end
 updatedFileContents << "\n"
end
 
#==============================================================
# Reading and updating the .h file contents
#==============================================================
 
if @position_prop_after_closing_bracket
 next_bracket = false
 hFileContents = IO.read(path)
 updatedHFileContents = ''
 hFileContents.split("\n").each do |line|
   next_bracket = true if line =~ /^@interface/
 
   if line =~ /^\}/ && next_bracket
     next_bracket = false
     updatedHFileContents << line + "\n" + properties.chomp
   else
     updatedHFileContents << line
   end
   updatedHFileContents << "\n"
 end
 
else
 
 next_bracket = false
  hFileContents = IO.read(path)
  updatedHFileContents = ''
  hFileContents.split("\n").each do |line|
    next_bracket = true if line =~ /^@interface/
 
    if line =~ /^\@end/ && next_bracket
      next_bracket = false
     updatedHFileContents << properties.chomp + "\n" + line
    else
      updatedHFileContents << line
    end
    updatedHFileContents << "\n"
  end
 
end
 
#==============================================================
# Update the Xcode .h and .m files with new content
#==============================================================
exit if replace_contents_leopard(mPath, updatedFileContents.chomp) == false
sleep SLEEP_TIME
replace_contents_leopard(path, updatedHFileContents.chomp)
find_doc_with_save(mPath)
find_doc_with_save(path)