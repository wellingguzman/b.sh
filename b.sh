#!/usr/bin/env bash

_global_variables() {
	g_root=$(pwd)
	g_posts_path="$g_root/posts"
	g_build_path="$g_root/public"
	g_site_title="Document title"
	g_site_description="Document description"
	g_markdown="$g_root/vendor/Markdown.pl"

	if [[ $(type -t global_variables) == 'function' ]]; then
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
g_POST_EXCERPT=5

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
		printf '%s' "$content" | $g_markdown
	else
		printf '%s' "$content"
	fi
}

convert_file()
{
	local path=$1

	if [[ -f "$g_markdown" ]]; then
		$g_markdown "$path"
	else
		cat "$path"
	fi
}

get_file_parts()
{
	local path=$1
	local title=""
	local tags=""
	local datetime=""
	local content=""
	local excerpt=""
	local tmp="$path.info.tmp"
	local part_start=0
	local part_done=0

	while IFS= read -r line
	do
		if [[ $line == "---" ]]; then
			if [[ $part_start == 1 ]]; then
				part_start=0
				part_done=1
			else
				part_start=1
			fi
			continue;
		fi

		if [[ $part_done == 0 && $part_start == 1 ]]; then
			if [[ $line == "title:"* ]]; then
				title=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
			elif [[ $line == "tags:"* ]]; then
				tags=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
			elif [[ $line == "datetime:"* ]]; then
				datetime=$(echo $line | cut -d: -f 2- | awk '{$1=$1};1')
			fi

			continue
		fi

		if [[ $line == "<!--more-->" ]]; then
			excerpt=$(get_content "$tmp")
			>$tmp
		else
			# content
			printf '%s\n' "$line" >> "$tmp"
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
		"$excerpt"
	)
}

build_page()
{
	local content=$1
	local title=$2;
	local target=$3

	if [[ ! -z "$title" ]]; then
		title="$title – $g_site_title"
	else
		title=$g_site_title
	fi

	{
		echo "<!doctype html>"
		echo "<html lang=\"en\">"
		echo "<head>"
		echo "<meta charset=\"utf-8\">"
		echo "<title>$title</title>"
		if [[ ! -z $g_site_description ]]; then
			echo "<meta name=\"description\" content=\"$g_site_description\">"
		fi
		echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
		echo "</head>"

		local styles_path="$g_root/_styles.css"
		if [[ -f "$styles_path" ]]; then
			echo "<style>"
			get_content "$styles_path"
			echo "</style>"
		fi

		echo "</head>"
		echo "<body>"
		echo "<div class=\"container\">"
		echo "<header>"
		echo "<h1><a href=\"/\">$g_site_title</a></h1>"
		echo "<p>$g_site_description</p>"
		echo "</header>"

		cat $content

		echo "</div>"
		echo "</body></html>"
	} > "$target"

	chmod 664 $target
}

create_post()
{
	local path=$1
	get_path_info "$path"
	local ext="${pathinfo[g_PATH_INFO_EXT]}"
	local name=$(get_name $path)

	local tmp="$path.tmp"
	local tmpContent="$path.content"
	local title=""
	local tags=""
	local datetime=""
	local content=""
	local part_start=0
	local part_done=0

	echo "Building $name..."
	echo "Reading metadata..."

	# TODO: Create a function to split metadata and content
	while IFS= read -r line
	do
		if [[ $line == "---" ]]; then
			if [[ $part_start == 1 ]]; then
				part_start=0
				part_done=1
			else
				part_start=1
			fi
			continue;
		fi

		if [[ $part_done == 0 && $part_start == 1 ]]; then
			if [[ $line == "title:"* ]]; then
				title=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
			elif [[ $line == "tags:"* ]]; then
				tags=$(echo $line | cut -d: -f 2 | awk '{$1=$1};1')
			elif [[ $line == "datetime:"* ]]; then
				datetime=$(echo $line | cut -d: -f 2- | awk '{$1=$1};1')
			fi

			continue
		fi

		# content
		printf '%s\n' "$line" >> "$tmpContent"
	done < "$path"

	{
		echo "<article>"
		echo "<h1 class=\"title\">$title</h1>"

		if [[ $ext == "md" ]]; then
			convert_file "$tmpContent"
		else
			get_content "$tmpContent"
		fi

		if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
			echo "<div class=\"meta\">"
		fi
		if [[ ! -z "$datetime" ]]; then
			echo "Date: <time>$datetime</time>"
		fi
		if [[ ! -z "$tags" ]]; then
			get_tags "$tags"
		fi
		if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
			echo "</div>"
		fi

		echo "</article>"
	} > "$tmp"

	rm $tmpContent

	build_page "$tmp" "$title" "$g_build_path/$name.html"
	rm $tmp
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
	local tmp="$g_posts_path/index.tmp";
	local filename;
	local files;

	mkdir -p $tmp_posts
	chmod 750 $tmp_posts
	>$tmp

	echo "Sorting posts..."
	for file in $(ls -d $g_posts_path/*.{html,md} 2>/dev/null); do
		name=$(get_basename $file)

		get_file_parts "$file"
		get_path_info "$file"
		local datetime=${parts[g_POST_DATETIME]}

		# TODO: Fix index page when all posts have no datetime
		if [[ -z "$datetime" ]]; then
			continue
		fi

		filename="${datetime//[:\-_+]/}_$name"
		
		local path="$tmp_posts/$filename.tmp"
		echo "---" > "$path"
		echo "title: ${parts[g_POST_TITLE]}" >> "$path"
		echo "datetime: ${parts[g_POST_DATETIME]}" >> "$path"
		echo "tags: ${parts[g_POST_TAGS]}" >> "$path"
		echo "---" >> "$path"
		if [[ ! -z "${parts[g_POST_EXCERPT]}" ]]; then
			printf '%s\n' "${parts[g_POST_EXCERPT]}" >> "$path"
			echo "<!--more-->" >> "$path"
		fi
		printf '%s\n' "${parts[g_POST_CONTENT]}" >> "$path"
	done

	echo "Generating posts index..."
	for file in $(ls -dr $tmp_posts/* 2>/dev/null); do
		get_file_parts "$file"
		title=${parts[g_POST_TITLE]}
		datetime=${parts[g_POST_DATETIME]}
		tags=${parts[g_POST_TAGS]}
		echo "${parts[g_POST_EXCERPT]}"
		if [[ ! -z "${parts[g_POST_EXCERPT]}" ]]; then
			content=${parts[g_POST_EXCERPT]}
		else
			content=${parts[g_POST_CONTENT]}
		fi

		file_name=$(get_basename "$file")
		file_name=${file_name%.tmp}
		get_path_info "$g_posts_path/$file_name"
		name="${pathinfo[g_PATH_INFO_NAME]}"
		ext="${pathinfo[g_PATH_INFO_EXT]}"
		orig_filename=$(get_name "$(echo "$file_name" | cut -d_ -f2-)")

		{
			echo "<article class=\"\">"
			if [[ -z "$title" ]]; then
				title="Untitled"
			fi
			echo "<h2><a href=\"$orig_filename.html\">$title</a></h2>"

			if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
				echo "<div class=\"meta\">"
			fi
			if [[ ! -z "$datetime" ]]; then
				echo "Date: <time>$datetime</time>"
			fi
			if [[ ! -z "$tags" ]]; then
				echo $(get_tags "$tags")
			fi
			if [[ ! -z "$datetime" ]] || [[ ! -z "$tags" ]]; then
				echo "</div>"
			fi

			if [[ $ext == "md" ]]; then
				convert_content "$content"
			else
				printf '%s' "$content"
			fi
			echo "</article>"
			echo "<hr>"
		} >> "$tmp"
	done

	build_page "$tmp" "" "$g_build_path/index.html"
	rm $tmp
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
		{
			echo "---"
			echo "title: "
			echo "datetime: $(date -u +%FT%TZ)"
			echo "tags: "
			echo "---"
			echo ""
		} >> "$path"
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
