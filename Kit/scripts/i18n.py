import os
import sys

PATH = os.getcwd()+"/Stats/Supporting Files/"

def get_keys(list):
	arr = []
	for el in list:
		if el.startswith("//") or len(el) == 0 or el == "\n":
			continue
		key = el.replace("\n", "").split(" = ")[0].replace('"', "")
		arr.append(key)

	return arr

def main():
	en_file = open(f"{PATH}/en.lproj/Localizable.strings", "r").readlines()
	if en_file == None:
		sys.exit("English language not found.")
	en_count = len(en_file)
	en_keys = get_keys(en_file)
	if len(en_keys) == 0:
		sys.exit("No English keys found.")

	languages = list(filter(lambda x: x.endswith(".lproj"), os.listdir(PATH)))
	
	for lang in languages:
		file = open(f"{PATH}/{lang}/Localizable.strings", "r").readlines()
		count = len(file)
		name = lang.replace(".lproj", "")
		keys = get_keys(file)
		if len(keys) == 0:
			sys.exit(f"No {name} keys found.")

		if count != en_count:
			print(f"`{lang}` has different number of lines ({count}) than English ({en_count})\n")

			for i, el in enumerate(en_keys):
				if el != keys[i]:
					sys.exit(f"line {i}: en=`{el}`; {name}=`{keys[i]}`\n")

	print(f"All fine, found {en_count} lines in {len(languages)} languages.")

if __name__ == "__main__":
    main()
