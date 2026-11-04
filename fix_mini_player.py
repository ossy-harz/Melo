with open('lib/features/player/mini_player.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove backslash before dollar signs
content = content.replace('\\$', '$')

with open('lib/features/player/mini_player.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

print('Fixed')
