import subprocess
import os
 
 
# Folder where all your scripts are
script_dir = r"C:\Users\josep\Documents\aVentaira\Python\Codes that work"

# List of scripts in the correct order
scripts = [
    "fetch_data.py",
    #"fetch_Locations.py",
    #"Upload_Parameters.py",
    "SQLtoJSON.py",
    "AQI_Calculations.py"
    
]

# Run each script one by one
for script in scripts:
    script_path = os.path.join(script_dir, script)
    print(f"🚀 Running {script}...")
    result = subprocess.run(["python", script_path], capture_output=True, text=True)

    if result.returncode != 0:
        print(f"BOO Error running {script}:\n{result.stderr}")
        break
    else:
        print(f"YAY!! Finished {script}\n{result.stdout}")

print("🎉 All scripts completed.")
