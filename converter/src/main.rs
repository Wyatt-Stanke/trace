use eyre::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path;
use usvg::{
    tiny_skia_path::{PathSegment, Point},
    NodeKind, Options, Path, Tree, TreeParsing,
};

#[derive(Debug, Serialize, Deserialize)]
struct Drawing {
    segments: Vec<FullUPoint>,
    meta: HashMap<String, String>,
}

impl Drawing {
    fn new(segments: Vec<FullUPoint>, meta: HashMap<String, String>) -> Self {
        Self { segments, meta }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct UPoint {
    x: u64,
    y: u64,
    // segment: u64,
}

impl From<Point> for UPoint {
    fn from(p: Point) -> Self {
        Self {
            x: p.x.round() as u64,
            y: p.y.round() as u64,
            // segment: 0,
        }
    }
}

impl UPoint {
    fn new(x: u64, y: u64) -> Self {
        Self {
            x,
            y,
            // segment: 0,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
struct FullUPoint {
    x: u64,
    y: u64,
    segment: u64,
}

impl FullUPoint {
    fn from_upoint(p: &UPoint, segment: u64) -> Self {
        Self {
            x: p.x,
            y: p.y,
            segment,
        }
    }
}

const RESOLUTION: u32 = 10;

// type UPoint = (u64, u64);

fn calculate_quad_bezier_point(p0: &UPoint, p1: &UPoint, p2: &UPoint, t: f64) -> UPoint {
    let x = (1.0 - t).powi(2) * p0.x as f64
        + 2.0 * (1.0 - t) * t * p1.x as f64
        + t.powi(2) * p2.x as f64;
    let y = (1.0 - t).powi(2) * p0.y as f64
        + 2.0 * (1.0 - t) * t * p1.y as f64
        + t.powi(2) * p2.y as f64;

    UPoint::new(x.round() as u64, y.round() as u64)
}

fn calculate_cubic_bezier_point(
    p0: &UPoint,
    p1: &UPoint,
    p2: &UPoint,
    p3: &UPoint,
    t: f64,
) -> UPoint {
    let x = (1.0 - t).powi(3) * p0.x as f64
        + 3.0 * (1.0 - t).powi(2) * t * p1.x as f64
        + 3.0 * (1.0 - t) * t.powi(2) * p2.x as f64
        + t.powi(3) * p3.x as f64;
    let y = (1.0 - t).powi(3) * p0.y as f64
        + 3.0 * (1.0 - t).powi(2) * t * p1.y as f64
        + 3.0 * (1.0 - t) * t.powi(2) * p2.y as f64
        + t.powi(3) * p3.y as f64;
    UPoint::new(x.round() as u64, y.round() as u64)
}

// TODO: Don't add the same point twice one after the other.
fn process_svg(svg: &str) -> Result<(Vec<FullUPoint>, HashMap<String, String>)> {
    let tree = Tree::from_str(svg, &Options::default()).unwrap();

    // let children = tree.root.children();

    let mut found_path: Option<Path> = None;
    let mut data: HashMap<String, String> = HashMap::new();

    // Crawling the tree
    for child in tree.root.descendants() {
        println!("Child: {:?}", child);

        if let NodeKind::Path(ref p) = *child.borrow() {
            println!("Found path! Id: {}", p.id);
            // if p.id == "Drawing" {
            println!("Found path!");
            found_path = Some(p.clone());
            // }
        }

        // Example text format:
        // <text id="Data" fill="white" xml:space="preserve" style="white-space: pre" font-family="Arial" font-size="20" font-weight="bold" letter-spacing="0em"><tspan x="5" y="259.434">#1:&#10;</tspan><tspan x="5" y="282.434">Difficulty: Hard&#10;</tspan><tspan x="5" y="305.434">Other: Property</tspan></text>
        // Get each property getting each tspan element
        if let NodeKind::Text(ref t) = *child.borrow() {
            println!("Found text! Id: {}", t.id);
            // if t.id == "Data" {
            for chunk in &t.chunks {
                println!("Chunk: {:?}", chunk);
                let text = chunk.text.clone();
                // If the chunk is in the format "Property: Value", we want to
                // extract the value.
                if let Some(colon_index) = text.find(':') {
                    let property = &text[..colon_index];
                    let value = &text[colon_index + 2..];
                    let name = match property {
                        "Difficulty" => "difficulty",
                        "Name" => "name",
                        _ => {
                            println!("Unknown property: {}", property);
                            continue;
                        }
                    };
                    if name.is_empty() || value.is_empty() {
                        continue;
                    }
                    data.insert(name.trim().to_string(), value.trim().to_string());
                }
            }
            // }
            println!("Data: {:?}", data);
        }
    }

    // Since we're converting to a system that uses non-floats, we need to
    // round the points to the nearest integer.
    let mut cursor = UPoint::new(0, 0);
    let mut segments: Vec<FullUPoint> = Vec::new();

    if let Some(path) = found_path {
        for (i, segment) in path.data.segments().enumerate() {
            println!("{:?}", segment);
            match segment {
                PathSegment::MoveTo(p) => {
                    cursor = p.into();
                    segments.push(FullUPoint::from_upoint(&cursor, i as u64));
                }
                PathSegment::LineTo(p) => {
                    cursor = p.into();
                    segments.push(FullUPoint::from_upoint(&cursor, i as u64));
                }
                PathSegment::Close => {}
                PathSegment::QuadTo(p1, p2) => {
                    for i in 0..RESOLUTION {
                        let t = i as f64 / RESOLUTION as f64;
                        let bezier_point =
                            calculate_quad_bezier_point(&cursor, &p1.into(), &p2.into(), t);
                        segments.push(FullUPoint::from_upoint(&bezier_point, i as u64));
                    }
                    cursor = p2.into();
                }
                PathSegment::CubicTo(p1, p2, p3) => {
                    let p0 = cursor;
                    for i in 0..RESOLUTION {
                        let t = i as f64 / RESOLUTION as f64;
                        let bezier_point = calculate_cubic_bezier_point(
                            &p0,
                            &p1.into(),
                            &p2.into(),
                            &p3.into(),
                            t,
                        );
                        segments.push(FullUPoint::from_upoint(&bezier_point, i as u64));
                    }
                    cursor = p3.into();
                }
            }
        }
        segments.dedup();
        println!("Path: {:?}", segments);
        Ok((segments, data))
    } else {
        println!("No path found!");
        Err(eyre::eyre!("No path found!"))
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        println!("Please provide the directory path as a command-line argument.");
        return;
    }

    let dir_path = &args[1];

    let dir_entries = fs::read_dir(dir_path).unwrap();

    let json_folder_path = path::Path::new(dir_path).join("out");
    fs::create_dir(&json_folder_path).unwrap();

    for entry in dir_entries {
        if let Ok(entry) = entry {
            let file_path = entry.path();
            if let Some(extension) = file_path.extension() {
                if extension == "svg" {
                    if let Ok(svg) = fs::read_to_string(&file_path) {
                        let path = process_svg(&svg).unwrap();
                        let drawing = Drawing::new(
                            path.0,
                            path.1
                                .into_iter()
                                .map(|(k, v)| (k, v.to_string()))
                                .collect(),
                        );
                        let json = serde_json::to_string(&drawing).unwrap();
                        let json_file_name = file_path.file_stem().unwrap();
                        let json_path =
                            json_folder_path.join(json_file_name).with_extension("json");
                        println!("Writing to {:?}", json_path);
                        fs::write(json_path, json).unwrap();
                    } else {
                        println!("Failed to read file: {:?}", file_path);
                    }
                }
            }
        }
    }
}
