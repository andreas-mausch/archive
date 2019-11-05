Example call:

```
find . -iname "*.jpg" -print0 | xargs -0 -n1 ./image.sh
```
