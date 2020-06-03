#!/usr/bin/env bash

_global_variables() {
	g_root=$(pwd)
	g_posts_path="$g_root/posts"
	g_build_path="$g_root/public"
	g_site_title="Document title"
	g_site_description="Document description"
	g_markdown="$g_root/vendor/Markdown.pl"

	if [ $(type -t global_variables) == 'function' ]; then
		global_variables
	fi
}

g_PATH_INFO_NAME=0
g_PATH_INFO_EXT=1
g_PATH_INFO_BASENAME=2

g_POST_PATH=0
g_POST_TITLE=1
g_POST_DATETIME=2
g_POST_TAGS=3
g_POST_CONTENT=4

get_ext()
{
	local path=$1
	local filename=$(basename -- "$path")
	local extension="${filename##*.}"

	echo "$extension"
}

get_name()
{
	local path=$1
	local filename=$(basename -- "$path")
	local extension="${filename##*.}"
	local filename="${filename%.*}"

	echo "$filename"
}

get_basename()
{
	local path=$1
	local filename=$(basename -- "$path")

	echo "$filename"
}

get_path_info()
{
	local name=$(get_name "$1")
	local ext=$(get_ext "$1")
	local basename=$name

	if [[ -z "$ext" ]]; then
		basename+=".$ext"
	fi

	pathinfo=(
		"$name"
		"$ext"
		"$basename"
	)
}

get_content()
{
	path=$1
	if [ -s "$path" ]; then
		cat $path
	else
		echo ""
	fi
}

convert_content()
{
	content=$1

	if [[ -f "$g_markdown" ]]; then
		echo "$1" | $g_markdown
	else
		echo "$1"
	fi
}

get_file_parts()
{
	local path=$1
	local title=""
	local tags=""
	local datetime=""
	local content=""
	local tmp="$path.info.tmp"

	while IFS= read -r line
	do
		if [[ $line == "title:"* ]]; then
			title=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
		elif [[ $line == "tags:"* ]]; then
			tags=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
		elif [[ $line == "datetime:"* ]]; then
			datetime=$(echo $line | cut -d: -f 2- | awk '{$1=$1};1')
		else
			echo "$line" >> "$tmp"
		fi
	done < "$path"

	content=$(get_content "$tmp")
	rm -rf "$tmp"

	parts=(
		"$path"
		"$title"
		"$datetime"
		"$tags"
		"$content"
	)
}

build_page()
{
	local content=$1
	local title=$2;

	if [[ ! -z "$title" ]]; then
		title="$title – $g_site_title"
	else
		title=$g_site_title
	fi

	echo "<!doctype html>" >> "$tmp"
	echo "<html lang=\"en\">" >> "$tmp"
	echo "<head>" >> "$tmp"
	echo "<meta charset=\"utf-8\">" >> "$tmp"
	echo "<title>$title</title>" >> "$tmp"
	if [[ ! -z $g_site_description ]]; then
		echo "<meta name=\"description\" content=\"$g_site_description\">" >> "$tmp"
	fi
	echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> "$tmp"
	echo "</head>" >> "$tmp"

	local styles_path="$g_root/_styles.css"
	if [[ -f "$styles_path" ]]; then
		styles=$(get_content "$styles_path")
		echo "<style>" >> "$tmp"
		echo $styles >> "$tmp"
		echo "</style>" >> "$tmp"
	fi

	echo "</head>" >> "$tmp"
	echo "<body>" >> "$tmp"
	echo "<div class=\"container\">" >> "$tmp"
	echo "<header>" >> "$tmp"
	echo "<h1><a href=\"/\">$g_site_title</a></h1>" >> "$tmp"
	echo "<p>$g_site_description</p>" >> "$tmp"
	echo "</header>" >> "$tmp"
	echo "$content" >> "$tmp"

	echo "</div>" >> "$tmp"
	echo "</body></html>" >> "$tmp"
}

create_post()
{
	local path=$1
	get_path_info "$path"
	local ext="${pathinfo[g_PATH_INFO_EXT]}"
	local name=$(get_name $path)

	local tmp="$path.tmp"
	local title=""
	local tags=""
	local datetime=""
	local content=""

	echo "Building $name..."
	echo "Reading metadata..."
	while IFS= read -r line
	do
		if [[ $line == "title:"* ]]; then
			title=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
		elif [[ $line == "tags:"* ]]; then
			tags=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
		elif [[ $line == "datetime:"* ]]; then
			datetime=$(echo $line | cut -d: -f 2- | awk '{$1=$1};1')
		else
			echo "$line" >> "$tmp"
		fi
	done < "$path"

	content=$(get_content "$tmp")
	if [[ $ext == "md" ]]; then
		echo "Converting to HTML..."
		content=$(convert_content "$content")
	fi

	>$tmp
	echo "<article>" >> "$tmp"
	echo "<h1 class=\"title\">$title</h1>" >> "$tmp"
	echo "$content" >> "$tmp"
	
	if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
		echo "<div class=\"meta\">" >> "$tmp"
	fi
	if [[ ! -z "$datetime" ]]; then
		echo "Date: <time>$datetime</time>" >> "$tmp"
	fi
	if [[ ! -z "$tags" ]]; then
		echo $(get_tags "$tags") >> "$tmp"
	fi
	if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
		echo "</div>" >> "$tmp"
	fi

	echo "</article>" >> "$tmp"

	page_content=$(get_content "$tmp")
	>$tmp
	build_page "$page_content" "$title"
	mv $tmp "$g_build_path/$name.html"
	chmod 664 "$g_build_path/$name.html"
}

get_tags()
{
	list=($1)

	echo "<div class=\"tags\">"
	echo "Tags: "
	echo "<ul>"
	for tag in "${list[@]}"; do
		echo "<li>"
		echo "$tag"
		echo "</li>"
	done
	echo "</ul>"
	echo "</div>"
}

build_all() {
	for file in $(ls -d $g_posts_path/*.{html,md} 2>/dev/null); do
		create_post $file
	done
}

rebuild_index()
{
	local tmp_posts="$g_root/.sort"
	local filename;
	local tmp;
	local files;

	mkdir -p $tmp_posts
	chmod 750 $tmp_posts

	echo "Sorting posts..."
	for file in $(ls -d $g_posts_path/*.{html,md} 2>/dev/null); do
		name=$(get_basename $file)

		get_file_parts "$file"
		get_path_info "$file"
		local datetime=${parts[g_POST_DATETIME]}

		if [[ -z "$datetime" ]]; then
			continue
		fi

		filename="${datetime//[:\-_+]/}_$name"
		
		local path="$tmp_posts/$filename.tmp"
		echo "title: ${parts[g_POST_TITLE]}" >> "$path"
		echo "datetime: ${parts[g_POST_DATETIME]}" >> "$path"
		echo "tags: ${parts[g_POST_TAGS]}" >> "$path"
		echo "${parts[g_POST_CONTENT]}" >> "$path"
	done

	echo "Generating posts index..."
	tmp="$g_posts_path/index.tmp"
	for file in $(ls -d $tmp_posts/* 2>/dev/null); do
		get_file_parts "$file"
		title=${parts[g_POST_TITLE]}
		datetime=${parts[g_POST_DATETIME]}
		tags=${parts[g_POST_TAGS]}
		content=${parts[g_POST_CONTENT]}

		file_name=$(get_basename "$file")
		file_name=${file_name%.tmp}
		get_path_info "$g_posts_path/$file_name"
		name="${pathinfo[g_PATH_INFO_NAME]}"
		ext="${pathinfo[g_PATH_INFO_EXT]}"
		orig_filename=$(get_name "$(echo "$file_name" | cut -d_ -f2-)")

		if [[ $ext == "md" ]]; then
			content=$(convert_content "$content")
		fi

		echo "<article class=\"\">" >> "$tmp"
		if [[ -z "$title" ]]; then
			title="Untitled"
		fi
		echo "<h2><a href=\"$orig_filename.html\">$title</a></h2>" >> "$tmp"
		echo "$content" >> "$tmp"
		if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
			echo "<div class=\"meta\">" >> "$tmp"
		fi
		if [[ ! -z "$datetime" ]]; then
			echo "Date: <time>$datetime</time>" >> "$tmp"
		fi
		if [[ ! -z "$tags" ]]; then
			echo $(get_tags "$tags") >> "$tmp"
		fi
		if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
			echo "</div>" >> "$tmp"
		fi
		echo "</article>" >> "$tmp"
		echo "<hr>" >> "$tmp"
	done

	page_content=$(get_content "$tmp")
	>$tmp
	build_page "$page_content"

	mv $tmp "$g_build_path/index.html"
	chmod 664 "$g_build_path/index.html"
	rm -rf "$tmp_posts"
}

edit()
{
	local path="$g_posts_path/$1"

	if [[ ! -f "$g_posts_path" ]]; then
		mkdir -p "$g_posts_path"
		chmod 744 "$g_posts_path"
	fi
	if [[ ! -f "$path" ]]; then
		echo "title: " >> "$path"
		echo "datetime: $(date -u +%FT%TZ)" >> "$path"
		echo "tags: " >> "$path"
		echo "" >> "$path"
	fi

	vim $path
	create_post $path
}

# Add custom variables
if [ -f "./extras.sh" ]; then
    . ./extras.sh
fi

_global_variables

if [[ ! -f "$g_build_path" ]]; then
	echo "Creating build path: $g_build_path"
	mkdir -p "$g_build_path"
	chmod 754 "$g_build_path"
fi

case $1 in
	# Build all posts
	"ba" )
		if [[ -d "$g_posts_path" ]]; then
			build_all
			rebuild_index
		else
			echo "No posts"
		fi
	;;
	
	# Build single post
	"b" )
		if [[ -f "$g_posts_path/$2" ]]; then
			create_post "$g_posts_path/$2"
			rebuild_index
		else
			echo "Post not found: $g_posts_path/$2"
		fi
	;;

	# Create/Edit posts
	"c" )
		edit $2
		rebuild_index
	;;
esac
