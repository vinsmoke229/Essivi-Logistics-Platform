import os
import re
import tokenize
from io import BytesIO

def remove_comments_python(source_code):
    """
    Remove comments from Python source code using tokenizer.
    Also fixes the 'utf-8' prefix bug from previous run.
    """
    # Fix the specific bug where 'utf-8' was prepended
    if source_code.startswith('utf-8'):
        source_code = source_code[5:]

    out = ""
    last_lineno = -1
    last_col = 0
    
    try:
        io_obj = BytesIO(source_code.encode('utf-8'))
        tokens = tokenize.tokenize(io_obj.readline)
        
        for token_type, token_string, (start_line, start_col), (end_line, end_col), line in tokens:
            if token_type == tokenize.ENCODING:
                continue # Skip encoding tokens completely

            if start_line > last_lineno:
                last_col = 0
            if start_col > last_col:
                out += " " * (start_col - last_col)
            
            if token_type == tokenize.COMMENT:
                pass # Skip comments
            elif token_type == tokenize.NL:
                out += token_string
            elif token_type == tokenize.NEWLINE:
                out += token_string
            else:
                out += token_string
                
            last_col = end_col
            last_lineno = end_line
            
        return out
    except tokenize.TokenError:
        return source_code 
    except Exception as e:
        print(f"Error processing python code: {e}")
        return source_code

def remove_comments_c_style(text):
    """
    Remove C-style comments (// and /* */) from text.
    Respects strings and regex literals to some extent.
    """
    def replacer(match):
        s = match.group(0)
        if s.startswith('/'):
            return " " # replace comment with space
        else:
            return s
            
    pattern = re.compile(
        r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"',
        re.DOTALL | re.MULTILINE
    )
    return re.sub(pattern, replacer, text)

def process_file(filepath):
    _, ext = os.path.splitext(filepath)
    ext = ext.lower()
    
    if ext not in ['.py', '.dart', '.ts', '.tsx', '.js', '.jsx', '.css', '.scss']:
        return

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        new_content = content
        
        if ext == '.py':
            new_content = remove_comments_python(content)
        else:
            new_content = remove_comments_c_style(content)
            
        # Write back if changed
        if new_content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Processed: {filepath}")
            
    except Exception as e:
        print(f"Failed to process {filepath}: {e}")

def main():
    dirs = ['backend', 'mobile_app', 'web_admin']
    base_dir = os.getcwd()
    
    for d in dirs:
        target_dir = os.path.join(base_dir, d)
        if not os.path.exists(target_dir):
            print(f"Directory not found: {target_dir}")
            continue
            
        print(f"Scanning {d}...")
        for root, _, files in os.walk(target_dir):
            if 'venv' in root or 'node_modules' in root or '.git' in root or '__pycache__' in root or 'build' in root or '.dart_tool' in root:
                continue
                
            for file in files:
                process_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
