import formidable from "formidable";
import { NextApiHandler } from "next";
import { File, NFTStorage } from "nft.storage";
import axios from "axios";
import { readFileSync, unlinkSync, writeFileSync } from "fs"; // Import the fs module functions

const client = new NFTStorage({ token: `${process.env.NFT_STORAGE_KEY}` });

const handler: NextApiHandler = async (req, res) => {
  if (req.method != "POST") {
    return res.status(403).json({ error: `Unsupported method ${req.method}` });
  }

  try {
    // Parse req body to get name, description, and image temp link
    const data: any = await new Promise((res, rej) => {
      const form = formidable({ multiples: true });
      form.parse(req, (err, fields, files) => {
        if (err) rej(err);
        res({ ...fields, ...files });
      });
    });

    console.log(data)

    // Download image from temp link using axios
    const imageTempLink = data.image;
    const imageResponse = await axios.get(imageTempLink, { responseType: "arraybuffer" });
    const arraybuffer = imageResponse.data;

    // Save a local copy of the downloaded image (optional)
    const localImagePath = "./image.png"; // Replace with the desired local path
    writeFileSync(localImagePath, arraybuffer);

    // Create a File instance from the downloaded image buffer
    const file = new File([arraybuffer], "image.png", {
      type: "image/png", // Set the MIME type to "image/png" for PNG images
    });

    // Upload data to nft.storage
    const metadata = await client.store({
      name: data.name,
      description: data.description,
      image: file,
    });

    // Return tokenURI
    res.status(201).json({ uri: metadata.url });
  } catch (e) {
    console.log(e);
    return res.status(400).json(e);
  }
};

export const config = {
  api: {
    bodyParser: false,
  },
};

export default handler;