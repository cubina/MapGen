//
//  ViewController.swift
//  Map Generator
//
//  Created by Carl Wieland on 4/23/15.
//  Copyright (c) 2015 Carl Wieland. All rights reserved.
//

import Cocoa
import Delaunay

class ViewController: NSViewController {

    var voronoiView: DelaunayView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Insert code here to initialize your application
        let relaxed = generateRelaxed(2000, seed: 412342)
        let points = relaxed(1000)
        let voronoi = Voronoi(points: points, colors: nil, plotBounds: Rectangle(x: 0, y: 0, width: 2000, height: 2000));
        self.voronoiView = DelaunayView(frame: CGRect(x: 0, y: 0, width: 3000, height: 3000))
        let scrollView = NSScrollView(frame:self.view.frame);
        scrollView.documentView = self.voronoiView
        scrollView.contentView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.translatesAutoresizingMaskIntoConstraints = true
        self.view.addSubview(scrollView)
        self.view.translatesAutoresizingMaskIntoConstraints = true
        func converter(_ p:Point)->CGPoint{
            return CGPoint(x: p.x, y: p.y)
        }
        
        for p in points {
            self.voronoiView.positions.append(converter(p))
            let region = voronoi.region(p);
            self.voronoiView.regionPoints.append(region.map(converter))
            
        }

    }
    
    
    
    // Generate points at random locations
    static func generateRandom(_ size:Int, seed:Int)->(_ numPoints:Int)->[Point] {
        func generator(_ numPoints:Int)->[Point] {
            let mapRandom = PM_PRNG();
            mapRandom.seed = UInt(seed)
            var points = [Point]();
            for _ in 0..<numPoints {
                let p = Point(x:Double(mapRandom.nextDoubleRange(10.0, max: Double(size)-10.0)),
                    y:Double(mapRandom.nextDoubleRange(10.0,max: Double(size)-10.0)));
                points.append(p);
            }
            return points;
        }
        return generator
    }
    
    func generateRelaxed(_ size:Int, seed:Int)->(Int)->[Point]{
        func relaxedGenerator(_ numPoints:Int)->[Point]{

            var voronoi:Voronoi
            var region:[Point];
            let points = ViewController.generateRandom(size, seed: seed)(numPoints);
            for _ in 0..<10 {
                voronoi = Voronoi(points: points, colors: nil, plotBounds: Rectangle(x: 0, y: 0, width: size, height: size));
                for pIn in points {
                    let p = pIn
                    region = voronoi.region(p);
                    p.x = 0.0;
                    p.y = 0.0;
                    for q in region{
                        p.x += q.x;
                        p.y += q.y;
                    }
                    p.x /= Double(region.count);
                    p.y /= Double(region.count);
                    
                }
                voronoi.dispose();
            }
            return points;
        }
        return relaxedGenerator
    }
}
