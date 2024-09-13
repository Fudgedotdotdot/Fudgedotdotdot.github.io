<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
# Inspired by https://github.com/onejar99/gitbook-build-publish-action

# function checkIfErr() {
#     ret=$?
#     echo "ret=[${ret}]"
#     if [ ! $ret = '0' ]; then
#         echo "Oops something wrong! exit code: ${ret}"
#         exit $ret;
#     fi
# }

>>>>>>> f02eb51 (Update docs)
>>>>>>> e02de8f (Updated with:  959d196))
>>>>>>> 5c52129 (Updated with:  273137f)
>>>>>>> 40673e7 (Updated with:  153343f)
>>>>>>> 2f34b91 (Updated with:  d763552)
>>>>>>> ab79ba2 (Updated with:  1008333)
>>>>>>> 31829a1 (Updated with:  d9fc0af)
>>>>>>> 7ba5c81 (Updated with:  db869ce)
>>>>>>> 996154c (Updated with:  546ac1e)
>>>>>>> 5e780d3 (Updated with:  40e6247)
>>>>>>> 87230ba (Updated with:  799fdcd)
>>>>>>> a89ae3f (Updated with:  f8e6be8)
>>>>>>> 4ef2826 (Updated with:  516f2bd)
>>>>>>> 4b589c7 (Updated with:  be93566)
echo '[INFO] Building static website...'
cd ${GITHUB_WORKSPACE}
git config --global --add safe.directory /github/workspace

<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> 7ba5c81 (Updated with:  db869ce)
>>>>>>> 996154c (Updated with:  546ac1e)
>>>>>>> 5e780d3 (Updated with:  40e6247)
>>>>>>> 87230ba (Updated with:  799fdcd)
>>>>>>> a89ae3f (Updated with:  f8e6be8)
>>>>>>> 4ef2826 (Updated with:  516f2bd)
>>>>>>> 4b589c7 (Updated with:  be93566)
npm install honkit-plugin-theme-darkening@1.0.3 --save-dev
# fix for theme
sed -i 's/gitbook-plugin-honkit-plugin-theme-darkening/honkit-plugin-theme-darkening/' node_modules/honkit-plugin-theme-darkening/index.js

npx honkit build

<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
<<<<<<< HEAD
=======
=======
<<<<<<< HEAD
npm install honkit-plugin-theme-darkening@1.0.3 --save-dev
# fix for theme
sed 's/gitbook-plugin-honkit-plugin-theme-darkening/honkit-plugin-theme-darkening/' node_modules/honkit-plugin-theme-darkening/index.js

npx honkit build

=======
<<<<<<< HEAD
npm install honkit-plugin-theme-darkening@1.0.3 --save-dev

npx honkit build

=======
<<<<<<< HEAD
npm install honkit-plugin-theme-darkening@1.0.3 --save-dev

honkit build

=======
<<<<<<< HEAD
npm install honkit-plugin-theme-darkening --save-dev

honkit build

=======
honkit build

<<<<<<< HEAD
=======
<<<<<<< HEAD
=======

>>>>>>> f02eb51 (Update docs)
>>>>>>> e02de8f (Updated with:  959d196))
>>>>>>> 5c52129 (Updated with:  273137f)
>>>>>>> 40673e7 (Updated with:  153343f)
>>>>>>> 2f34b91 (Updated with:  d763552)
>>>>>>> ab79ba2 (Updated with:  1008333)
>>>>>>> 31829a1 (Updated with:  d9fc0af)
>>>>>>> 7ba5c81 (Updated with:  db869ce)
>>>>>>> 996154c (Updated with:  546ac1e)
>>>>>>> 5e780d3 (Updated with:  40e6247)
>>>>>>> 87230ba (Updated with:  799fdcd)
>>>>>>> a89ae3f (Updated with:  f8e6be8)
>>>>>>> 4ef2826 (Updated with:  516f2bd)
>>>>>>> 4b589c7 (Updated with:  be93566)
echo '[INFO] Some magic to merge main into gh-pages...'
git fetch origin gh-pages --depth 1
git checkout gh-pages
git rebase main

<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
<<<<<<< HEAD
cp -R _book/* .
=======
cp -R _book/* .s
>>>>>>> f02eb51 (Update docs)
>>>>>>> e02de8f (Updated with:  959d196))
>>>>>>> 5c52129 (Updated with:  273137f)
>>>>>>> 40673e7 (Updated with:  153343f)
>>>>>>> 2f34b91 (Updated with:  d763552)
>>>>>>> ab79ba2 (Updated with:  1008333)
>>>>>>> 31829a1 (Updated with:  d9fc0af)
>>>>>>> 7ba5c81 (Updated with:  db869ce)
>>>>>>> 996154c (Updated with:  546ac1e)
>>>>>>> 5e780d3 (Updated with:  40e6247)
>>>>>>> 87230ba (Updated with:  799fdcd)
>>>>>>> a89ae3f (Updated with:  f8e6be8)
>>>>>>> 4ef2826 (Updated with:  516f2bd)
>>>>>>> 4b589c7 (Updated with:  be93566)
git clean -fx node_modules
git clean -fx _book
git add .

git config --local user.name "Fudgedotdotdot"
git config --local user.email "28399056+Fudgedotdotdot@users.noreply.github.com"

<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7)"
git push origin HEAD:gh-pages --force
git checkout main
=======
<<<<<<< HEAD
echo '[INFO] Pushing gh-pages...'
git commit -am "Updated with:  $(echo $GITHUB_SHA | cut -c1-7))"
git push origin HEAD:gh-pages --force
git checkout main
=======
git commit -am "Update docs"
git push origin HEAD:gh-pages --force
git checkout main
>>>>>>> f02eb51 (Update docs)
>>>>>>> e02de8f (Updated with:  959d196))
>>>>>>> 5c52129 (Updated with:  273137f)
>>>>>>> 40673e7 (Updated with:  153343f)
>>>>>>> 2f34b91 (Updated with:  d763552)
>>>>>>> ab79ba2 (Updated with:  1008333)
>>>>>>> 31829a1 (Updated with:  d9fc0af)
>>>>>>> 7ba5c81 (Updated with:  db869ce)
>>>>>>> 996154c (Updated with:  546ac1e)
>>>>>>> 5e780d3 (Updated with:  40e6247)
>>>>>>> 87230ba (Updated with:  799fdcd)
>>>>>>> a89ae3f (Updated with:  f8e6be8)
>>>>>>> 4ef2826 (Updated with:  516f2bd)
>>>>>>> 4b589c7 (Updated with:  be93566)
