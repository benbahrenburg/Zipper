/**
 * This example demonstrates how to zip and unzip files.
 *
 * We'll demonstrate this in two different ways:
 *  - Zipping files.
 *  - Unzipping an archive.
 */
var win = Ti.UI.createWindow({
    backgroundColor: 'white'
});
win.open();

var Compression = require('bencoding.zip');
var outputDirectory = Ti.Filesystem.applicationDataDirectory;
var inputDirectory = Ti.Filesystem.resourcesDirectory + 'data/';

/**
 * The following lines zip the a.txt and b.txt from the "data"
 * directory in your resources to the data directory of your app.
 */
var zipFiles = Ti.UI.createButton({
    title: 'Zip a.txt and b.txt',
    top: 20, left: 20, right: 20,
    height: 40
});
function onComplete(e){
	Ti.API.info(JSON.stringify(e));
};
zipFiles.addEventListener('click', function () {
    var writeToZip = outputDirectory + '/zipFiles.zip';

    Compression.zip({
    		zip: writeToZip, 
    		password:"foo",
    		files: [inputDirectory + 'a.txt',
        	inputDirectory + 'b.txt'],
        	completed:onComplete
    });
});
win.add(zipFiles);

/**
 * The following lines extract the contents of the "a+b.zip" file
 * from the "data" directory in your resources to the data directory
 * of your app.
 */
var unzipArchive = Ti.UI.createButton({
    title: 'Unzip ab.zip',
    top: 80, left: 20, right: 20,
    height: 40
});
unzipArchive.addEventListener('click', function () {
    var zipFileName = inputDirectory + 'ab.zip';
    Compression.unzip({
    	outputDirectory:outputDirectory, 
    	zip:zipFileName, 
    	overwrite:true,
    	completed:onComplete
    });

});
win.add(unzipArchive);

var status = Ti.UI.createLabel({
    text: 'Hit one of the buttons above, and the result will display here.',
    color: '#333',
    top: 140, left: 20, right: 20, bottom: 20
});
win.add(status);