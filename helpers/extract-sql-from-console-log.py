import re

infilePath = '../exercises/exercise_01_borrowing_returning.txt'
outfilePath = f'{infilePath}.sql'

with open(infilePath, 'r', encoding='utf-8') as infile, open(outfilePath, 'w', encoding='utf-8') as outfile:
    for line in infile:
        #outfile.write(line)
        eval = re.match(r'mysql>(.*)\s*', line)
        if eval:
            #print(eval.group(1))
            outfile.write(f'{eval.group(1)}\n')
            
