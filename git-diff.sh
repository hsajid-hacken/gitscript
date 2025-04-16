#!/bin/bash

echo "🔍 Git Fork Diff Analyzer (Cross-Repo)"
echo "======================================"

# ---- Config Prompt ----
read -p "Enter the path to the official (open-source) repo: " official_repo_path
read -p "Enter the path to the custom (forked/manual) repo: " custom_repo_path
read -p "Enter the branch to check in the official repo : " official_branch
read -p "Enter the branch to check in the custom repo : " custom_branch
read -p "Enter the commit hash from custom repo branch '$custom_branch' that need to be audited: " audit_commit

official_branch=${official_branch:-master}
custom_branch=${custom_branch:-master}

# ---- Reusable Summary Function ----
print_diff_summary() {
    local base_commit="$1"
    local target_commit="$2"

    echo ""
    echo "📄 Line Change Summary"
    echo "----------------------"
    echo "🧱 Base Commit (official repo) : $base_commit"
    echo "🔧 Target Commit (custom repo) : $target_commit"
    echo ""

    output_file="diff_summary_${target_commit:0:8}.txt"
    echo "📊 Summary" > "$output_file"
    echo "----------" >> "$output_file"
    echo "Base Commit  : $base_commit" >> "$output_file"
    echo "Target Commit: $target_commit" >> "$output_file"
    echo "" >> "$output_file"

    # Get detailed file changes
    echo "📂 File Changes Analysis" >> "$output_file"
    echo "------------------------" >> "$output_file"
    
    # Get newly added files (excluding .Zone.Identifier files)
    echo "🆕 Newly Added Files & Folders:" >> "$output_file"
    temp_file=$(mktemp)
    git diff --name-only --diff-filter=A "$base_commit" "$target_commit" | grep -v ':Zone.Identifier$' | while read -r file; do
        # Get line count for the file
        line_count=$(git show "$target_commit:$file" 2>/dev/null | wc -l || echo 0)
        if [ -d "$file" ]; then
            echo "  + $file (directory)" >> "$output_file"
        else
            # Check if file is a code file (not config)
            if [[ ! "$file" =~ \.(json|yml|yaml|git|md|txt|log|lock|toml|ini|cfg|conf|config|properties|abi)$ ]]; then
                echo "$line_count" >> "$temp_file"
            fi
            echo "  + $file (${line_count} lines)" >> "$output_file"
        fi
    done
    echo "" >> "$output_file"
    
    # Calculate total lines of code
    total_code_lines=$(awk '{sum += $1} END {print sum}' "$temp_file" 2>/dev/null || echo 0)
    rm -f "$temp_file"
    echo "  Total new lines of code: $total_code_lines" >> "$output_file"
    echo "" >> "$output_file"

    # Get deleted files
    echo "🗑️ Deleted Files:" >> "$output_file"
    git diff --name-only --diff-filter=D "$base_commit" "$target_commit" | while read -r file; do
        echo "  - $file" >> "$output_file"
    done
    echo "" >> "$output_file"

    # Get renamed/moved files
    echo "🔄 Renamed/Moved Files:" >> "$output_file"
    temp_counts=$(mktemp)
    git diff --name-status --diff-filter=R "$base_commit" "$target_commit" | while read -r status old_file new_file; do
        tmp_official=$(mktemp)
        tmp_custom=$(mktemp)

        # Get content from old file in official repo
        if git -C "$official_repo_path" cat-file -e "$base_commit:$old_file" 2>/dev/null; then
            git -C "$official_repo_path" show "$base_commit:$old_file" > "$tmp_official"
        else
            touch "$tmp_official"
        fi

        # Get content from new file in custom repo
        if git -C "$custom_repo_path" cat-file -e "$target_commit:$new_file" 2>/dev/null; then
            git -C "$custom_repo_path" show "$target_commit:$new_file" > "$tmp_custom"
        else
            touch "$tmp_custom"
        fi

        if [[ -s "$tmp_official" || -s "$tmp_custom" ]]; then
            additions=$(diff -u "$tmp_official" "$tmp_custom" | grep -E '^\+[^+]' | wc -l | tr -d ' ')
            deletions=$(diff -u "$tmp_official" "$tmp_custom" | grep -E '^\-[^-]' | wc -l | tr -d ' ')
            
            # Only show files with actual changes
            if [ "$additions" -gt 0 ] || [ "$deletions" -gt 0 ]; then
                echo "  ↪️ $old_file → $new_file (${additions}+/${deletions}-)" >> "$output_file"
                # Only add to total if it's a code file
                if [[ ! "$new_file" =~ \.(json|yml|yaml|git|md|txt|log|lock|toml|ini|cfg|conf|config|properties|abi)$ ]]; then
                    echo "$additions $deletions" >> "$temp_counts"
                fi
            else
                echo "  ↪️ $old_file → $new_file" >> "$output_file"
            fi
        fi

        rm -f "$tmp_official" "$tmp_custom"
    done
    echo "" >> "$output_file"
    
    # Calculate total changes from temp file
    total_additions=$(awk '{sum += $1} END {print sum}' "$temp_counts" 2>/dev/null || echo 0)
    total_deletions=$(awk '{sum += $2} END {print sum}' "$temp_counts" 2>/dev/null || echo 0)
    rm -f "$temp_counts"
    
    echo "  Total code changes in renamed files: ${total_additions}+/${total_deletions}-" >> "$output_file"
    echo "" >> "$output_file"

    # Get modified files with actual changes
    echo "📝 Modified Files:" >> "$output_file"
    temp_counts=$(mktemp)
    git diff --name-only --diff-filter=M "$base_commit" "$target_commit" | grep -v ':Zone.Identifier$' | while read -r file; do
        tmp_official=$(mktemp)
        tmp_custom=$(mktemp)

        # Official version
        if git -C "$official_repo_path" cat-file -e "$base_commit:$file" 2>/dev/null; then
            git -C "$official_repo_path" show "$base_commit:$file" > "$tmp_official"
        else
            touch "$tmp_official"
        fi

        # Custom version
        if git -C "$custom_repo_path" cat-file -e "$target_commit:$file" 2>/dev/null; then
            git -C "$custom_repo_path" show "$target_commit:$file" > "$tmp_custom"
        else
            touch "$tmp_custom"
        fi

        if [[ -s "$tmp_official" || -s "$tmp_custom" ]]; then
            additions=$(diff -u "$tmp_official" "$tmp_custom" | grep -E '^\+[^+]' | wc -l | tr -d ' ')
            deletions=$(diff -u "$tmp_official" "$tmp_custom" | grep -E '^\-[^-]' | wc -l | tr -d ' ')
            
            # Only show files with actual changes
            if [ "$additions" -gt 0 ] || [ "$deletions" -gt 0 ]; then
                echo "  * $file (${additions}+/${deletions}-)" >> "$output_file"
                # Only add to total if it's a code file
                if [[ ! "$file" =~ \.(json|yml|yaml|git|md|txt|log|lock|toml|ini|cfg|conf|config|properties|abi)$ ]]; then
                    echo "$additions $deletions" >> "$temp_counts"
                fi
            fi
        fi

        rm -f "$tmp_official" "$tmp_custom"
    done
    echo "" >> "$output_file"
    
    # Calculate total changes from temp file
    total_additions=$(awk '{sum += $1} END {print sum}' "$temp_counts" 2>/dev/null || echo 0)
    total_deletions=$(awk '{sum += $2} END {print sum}' "$temp_counts" 2>/dev/null || echo 0)
    rm -f "$temp_counts"
    
    echo "  Total code changes in modified files: ${total_additions}+/${total_deletions}-" >> "$output_file"
    echo "" >> "$output_file"

    echo "📂 Files Affected are saved to: $output_file"
}

# ---- Fork Detection Function ----
check_fork_status() {
    echo "📥 Fetching branch '$official_branch' from official repo..."
    git fetch official-temp "$official_branch" --quiet || { echo "❌ Failed to fetch official branch."; exit 1; }

    # Simple checkout of custom branch
    echo "📥 Checking out branch '$custom_branch' in custom repo..."
    git checkout "$custom_branch" --quiet || { echo "❌ Failed to checkout custom branch."; exit 1; }

    echo "🔍 Checking for common Git history..."
    merge_base=$(git merge-base "$custom_branch" "official-temp/$official_branch")

    if [ -z "$merge_base" ]; then
        echo "⚠️  No common Git history found."
        return 1
    else
        echo "✅ Repositories share Git history."
        echo "🔗 Fork Point Commit: $merge_base"
        return 0
    fi
}

# ---- Known Manual Copy Shortcut ----
prompt_for_manual_or_auto() {
    echo ""
    echo "🧠 Do you already know the official commit from which the code was manually copied?"
    echo "1) ✅ Yes, I know the commit hash"
    echo "2) 🔍 No, please help me find it"
    read -p "Choose [1 or 2]: " mode

    if [ "$mode" == "1" ]; then
        read -p "Enter the known commit hash from official repo: " known_official_commit

        tmp_official="/tmp/manual_compare_known_official"
        tmp_custom="/tmp/manual_compare_custom"

        rm -rf "$tmp_official" "$tmp_custom"
        mkdir -p "$tmp_official" "$tmp_custom"

        echo "📥 Checking out $known_official_commit in official repo..."
        cd "$official_repo_path"
        git --work-tree="$tmp_official" checkout "$known_official_commit" --quiet .

        echo "📥 Checking out $audit_commit in custom repo..."
        cd "$custom_repo_path"
        git --work-tree="$tmp_custom" checkout "$audit_commit" --quiet .

        print_diff_summary "$known_official_commit" "$audit_commit"

        # Cleanup
        rm -rf "$tmp_official" "$tmp_custom"
        cd "$custom_repo_path" && git checkout "$custom_branch" --quiet
        cd "$official_repo_path" && git checkout "$official_branch" --quiet
        git remote remove official-temp >/dev/null 2>&1
        exit 0
    fi
    # If user chooses option 2, we will proceed to find the commit in find_manual_copy_base function
}

# ---- Unknown Manual Copy Detection ----
find_manual_copy_base() {
    echo "🔍 Manual Copy Detected"
    echo "------------------------------------------------------"

    prompt_for_manual_or_auto

    echo ""
    echo "⏳ Enter timeframe for likely copy origin in official repo"
    echo "Format: YYYY-MM-DD (e.g. 2022-01-01)"
    read -p "Start date: " start_date
    read -p "End date  : " end_date

    cd "$custom_repo_path"
    oldest_commit=$(git rev-list --max-parents=0 "$custom_branch")
    echo "📦 Oldest commit in custom repo: $oldest_commit"

    tmp_custom="/tmp/custom_oldest_checkout"
    rm -rf "$tmp_custom"
    mkdir -p "$tmp_custom"
    git --work-tree="$tmp_custom" checkout "$oldest_commit" --quiet . || {
        echo "❌ Failed to checkout oldest commit of custom repo."
        exit 1
    }

    cd "$official_repo_path"
    commit_list=$(git rev-list --reverse --since="$start_date" --before="$end_date" "$official_branch")

    echo ""
    echo "🔍 Scanning ${#commit_list[@]} commits from $start_date → $end_date for closest match..."

    best_match=""
    min_diff_count=-1

    for commit in $commit_list; do
        tmp_commit_dir="/tmp/official_commit_$commit"
        rm -rf "$tmp_commit_dir"
        mkdir -p "$tmp_commit_dir"

        git archive "$commit" | tar -x -C "$tmp_commit_dir"

        diff_output=$(diff -r "$tmp_commit_dir" "$tmp_custom")
        diff_count=$(echo "$diff_output" | wc -l)

        echo "⏱ Commit $commit → $diff_count line differences"

        if [ "$min_diff_count" -eq -1 ] || [ "$diff_count" -lt "$min_diff_count" ]; then
            min_diff_count=$diff_count
            best_match=$commit
        fi

        if [ "$diff_count" -eq 0 ]; then
            echo "🎯 Exact match found at commit: $commit"
            break
        fi

        # Check if file structure is changed
        file_structure_diff=$(diff -r --brief "$tmp_commit_dir" "$tmp_custom" | grep -v "Only in")
        if [ -z "$file_structure_diff" ]; then
            echo "📂 File structure is changed at commit: $commit"
            break
        fi

        rm -rf "$tmp_commit_dir"
    done

    echo ""
    echo "📌 Best matching commit from official repo: $best_match"
    echo "🔁 Difference lines: $min_diff_count"

    # Prepare clean checkout of audit commit
    tmp_custom_audit="/tmp/custom_audit_commit"
    rm -rf "$tmp_custom_audit"
    mkdir -p "$tmp_custom_audit"

    cd "$custom_repo_path"
    git --work-tree="$tmp_custom_audit" checkout "$audit_commit" --quiet . || {
        echo "❌ Failed to checkout audit commit."
        exit 1
    }

    # Prepare clean checkout of best_match official commit
    tmp_commit_dir_best="/tmp/best_match_commit"
    rm -rf "$tmp_commit_dir_best"
    mkdir -p "$tmp_commit_dir_best"

    cd "$official_repo_path"
    git archive "$best_match" | tar -x -C "$tmp_commit_dir_best"

    cd "$custom_repo_path"
    git remote add temp_origin "$official_repo_path" 2>/dev/null
    git fetch temp_origin "$official_branch" --quiet

    print_diff_summary "$best_match" "$audit_commit"

    git remote remove temp_origin >/dev/null 2>&1
    rm -rf "$tmp_custom" "$tmp_commit_dir_best" "$tmp_custom_audit"
    cd "$official_repo_path" && git checkout "$official_branch" --quiet
    cd "$custom_repo_path" && git checkout "$custom_branch" --quiet
}

# ---- Fork Branch Comparison ----
diff_between_commits() {
    print_diff_summary "$merge_base" "$audit_commit"
}

# ==== MAIN ====

cd "$custom_repo_path" || { echo "❌ Cannot access custom repo."; exit 1; }

# Add remote if not already added
if ! git remote | grep -q official-temp; then
    git remote add official-temp "$official_repo_path"
fi

# If shared history exists, follow fork diff logic
if check_fork_status; then
    diff_between_commits
else
    find_manual_copy_base
fi

git remote remove official-temp >/dev/null 2>&1
