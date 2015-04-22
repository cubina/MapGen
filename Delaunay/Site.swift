import Foundation

public final class Site:ICoord,IDisposable{
		private static var pool:[Site] = [Site]();
		public static func create(p:CGPoint, index:Int, weight:CGFloat, color:UInt)->Site
		{
			if (pool.count > 0)
			{
				return pool.removeLast().refresh(p, index: index, weight: weight, color: color);
			}
			else
			{
				return  Site( p: p, index: index, weight: weight, color: color);
			}
		}

		static func sortSites(inout sites:[Site])
		{
			sites.sort(Site.compare);
		}
//
//		/**
//		 * sort sites on y, then x, coord
//		 * also change each site's _siteIndex to match its new position in the list
//		 * so the _siteIndex can be used to identify the site for nearest-neighbor queries
//		 * 
//		 * haha "also" - means more than one responsibility...
//		 * 
//		 */
		private static func compare(s1:Site, s2:Site) -> Bool
		{
			var returnValue:Int = Voronoi.compareByYThenX(s1, s2: s2);
			
			// swap _siteIndex values if necessary to match new ordering:
			var tempIndex:Int;
			if (returnValue == -1)
			{
				if (s1.siteIndex > s2.siteIndex)
				{
					tempIndex = s1.siteIndex;
					s1.siteIndex = s2.siteIndex;
					s2.siteIndex = tempIndex;
				}
			}
			else if (returnValue == 1)
			{
				if (s2.siteIndex > s1.siteIndex)
				{
					tempIndex = s2.siteIndex;
					s2.siteIndex = s1.siteIndex;
					s1.siteIndex = tempIndex;
				}
				
			}
			
			return returnValue <= 0;
		}


		private static let EPSILON:CGFloat = 0.005;
		private static func closeEnough(p0:CGPoint, p1:CGPoint)->Bool
		{
			return CGPoint.distance(p0, p1) < EPSILON;
		}

		public var coord:CGPoint = CGPoint.zeroPoint;

		
		var color:UInt = 0;
		var weight:CGFloat = 0;

		private var siteIndex:Int = 0;

		// the edges that define this Site's Voronoi region:
		private var edges:[Edge] = [Edge]();
    
		// which end of each edge hooks up with the previous edge in _edges:
		private var edgeOrientations = [LR]();
		// ordered list of points that define the region clipped to bounds:
		private var region = [CGPoint]();

		public init( p:CGPoint, index:Int, weight:CGFloat, color:UInt)
		{
			refresh(p, index: index, weight: weight, color: color);
		}
		
		private func refresh(p:CGPoint, index:Int, weight:CGFloat, color:UInt)->Site
		{
			coord = p;
			siteIndex = index;
			self.weight = weight;
			self.color = color;
			edges.removeAll(keepCapacity: true)
			region.removeAll(keepCapacity: true)
			return self
		}
//
//		public func toString()->String
//		{
//			return "Site " + _siteIndex + ": " + coord;
//		}
//		
		private func move(p:CGPoint)
		{
			clear();
			coord = p;
		}

		public func dispose()
		{
			coord = CGPoint.zeroPoint;
			clear();
			Site.pool.append(self);
		}

		private func clear()
		{
            edges.removeAll(keepCapacity: true)
            edgeOrientations.removeAll(keepCapacity: true)
			region.removeAll(keepCapacity: true)
		}

        func addEdge(edge:Edge)
		{
			edges.append(edge);
		}

		func nearestEdge()->Edge
		{
			edges.sort(Edge.compareSitesDistances);
			return edges[0];
		}

		func neighborSites()->[Site]
		{
			if (edges.count == 0)
			{
				return [Site]();
			}
			if (edgeOrientations.count == 0)
			{ 
				reorderEdges();
			}
			var list = [Site]();

			for edge in edges
			{
                if let site = neighborSite(edge){
                    list.append(site);
                }
			}
			return list;
		}
			
		private func neighborSite(edge:Edge)->Site?
		{
			if (self === edge.leftSite)
			{
				return edge.rightSite;
			}
			if (self === edge.rightSite)
			{
				return edge.leftSite;
			}
			return nil;
		}
		
		func region(clippingBounds:CGRect)->[CGPoint]
		{
			if (edges.count == 0)
			{
				return [CGPoint]();
			}
			if (edgeOrientations.count == 0)
			{ 
				reorderEdges();
				region = clipToBounds(clippingBounds);
                if (( Polygon(vertices:region)).winding() == Winding.CLOCKWISE)
				{
					region = region.reverse();
				}
			}
			return region;
		}

		private func reorderEdges()
		{
			//trace("_edges:", _edges);
			var reorderer:EdgeReorderer = EdgeReorderer(origEdges: edges, criterion: .Vertex);
			edges = reorderer.edges;
			//trace("reordered:", _edges);
			edgeOrientations = reorderer.edgeOrientations;
			reorderer.dispose();
		}

		private func clipToBounds(bounds:CGRect) -> [CGPoint]
		{
			var points:[CGPoint] = [CGPoint]();
			var n:Int = edges.count;
			var i:Int = 0;
			var edge:Edge;
			while (i < n && (edges[i].visible == false))
			{
				++i;
			}
			
			if (i == n)
			{
				// no edges visible
				return [CGPoint]();
			}
			edge = edges[i];
			var orientation:LR = edgeOrientations[i];
			points.append(edge.clippedVertices[orientation]!);
			points.append(edge.clippedVertices[LR.other(orientation)]!);
			
			for (var j:Int = i + 1; j < n; ++j)
			{
				edge = edges[j];
				if (edge.visible == false)
				{
					continue;
				}
				connect(&points, j: j, bounds: bounds);
			}
			// close up the polygon by adding another corner point of the bounds if needed:
			connect(&points, j: i, bounds: bounds, closingUp: true);
			
			return points;
		}

		private func connect(inout points:[CGPoint], j:Int, bounds:CGRect, closingUp:Bool = false)
		{
			var rightPoint:CGPoint = points[points.count - 1];
			var newEdge:Edge = edges[j] as Edge;
			var newOrientation:LR = edgeOrientations[j];
			// the point that  must be connected to rightPoint:
			var newPoint:CGPoint = newEdge.clippedVertices[newOrientation]!;
			if (!Site.closeEnough(rightPoint, p1: newPoint))
			{
				// The points do not coincide, so they must have been clipped at the bounds;
				// see if they are on the same border of the bounds:
				if (rightPoint.x != newPoint.x
				&&  rightPoint.y != newPoint.y)
				{
					// They are on different borders of the bounds;
					// insert one or two corners of bounds as needed to hook them up:
					// (NOTE this will not be correct if the region should take up more than
					// half of the bounds rect, for then we will have gone the wrong way
					// around the bounds and included the smaller part rather than the larger)
					var rightCheck:Int = BoundsCheck.check(rightPoint, bounds: bounds);
					var newCheck:Int = BoundsCheck.check(newPoint, bounds: bounds);
					var px:CGFloat, py:CGFloat;
					if (rightCheck & BoundsCheck.RIGHT != 0)
					{
						px = bounds.maxX;
						if (newCheck & BoundsCheck.BOTTOM != 0)
						{
							py = bounds.minY;
							points.append(CGPoint(x: px, y: py));
						}
						else if (newCheck & BoundsCheck.TOP != 0)
						{
							py = bounds.maxY;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.LEFT != 0)
						{
							if (rightPoint.y - bounds.origin.y + newPoint.y - bounds.origin.y < bounds.height)
							{
								py = bounds.maxY;
							}
							else
							{
								py = bounds.minY;
							}
                            points.append(CGPoint(x:px,y: py));
                            points.append(CGPoint(x:bounds.minX,y: py));
						}
					}
					else if (rightCheck & BoundsCheck.LEFT != 0)
					{
						px = bounds.minX;
						if (newCheck & BoundsCheck.BOTTOM != 0)
						{
							py = bounds.minY;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.TOP != 0)
						{
							py = bounds.maxY;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.RIGHT != 0)
						{
							if (rightPoint.y - bounds.origin.y + newPoint.y - bounds.origin.y < bounds.height)
							{
								py = bounds.maxY;
							}
							else
							{
								py = bounds.minY;
							}
                            points.append(CGPoint(x:px,y: py));
                            points.append(CGPoint(x:bounds.maxX,y: py));
						}
					}
					else if (rightCheck & BoundsCheck.TOP != 0)
					{
						py = bounds.maxY;
						if (newCheck & BoundsCheck.RIGHT != 0)
						{
							px = bounds.maxX;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.LEFT != 0)
						{
							px = bounds.minX;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.BOTTOM != 0)
						{
							if (rightPoint.x - bounds.origin.x + newPoint.x - bounds.origin.x < bounds.width)
							{
								px = bounds.minX;
							}
							else
							{
								px = bounds.maxX;
							}
                            points.append(CGPoint(x:px,y: py));
                            points.append(CGPoint(x:px,y: bounds.minY));
						}
					}
					else if (rightCheck & BoundsCheck.BOTTOM != 0)
					{
						py = bounds.minY;
						if (newCheck & BoundsCheck.RIGHT != 0)
						{
							px = bounds.maxX;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.LEFT != 0)
						{
							px = bounds.minX;
                            points.append(CGPoint(x:px,y: py));
						}
						else if (newCheck & BoundsCheck.TOP != 0)
						{
							if (rightPoint.x - bounds.origin.x + newPoint.x - bounds.origin.x < bounds.width)
							{
								px = bounds.minX;
							}
							else
							{
								px = bounds.maxX;
							}
                            points.append(CGPoint(x:px,y: py));
                            points.append(CGPoint(x:px,y: bounds.maxY));
						}
					}
				}
				if (closingUp)
				{
					// newEdge's ends have already been added
					return;
				}
				points.append(newPoint);
			}
			var newRightPoint:CGPoint = newEdge.clippedVertices[LR.other(newOrientation)]!;
			if (!Site.closeEnough(points[0], p1: newRightPoint))
			{
				points.append(newRightPoint);
			}
		}
//
        var x:CGFloat
		{
			return coord.x;
		}
        var y:CGFloat{
			return coord.y;
		}

        func dist(p:ICoord)->CGFloat{
			return CGPoint.distance(p.coord, coord);
		}
}

public class BoundsCheck
{
    public static let TOP:Int = 1;
    public static let BOTTOM:Int = 2;
    public static let LEFT:Int = 4;
    public static let RIGHT:Int = 8;
    
    /**
     * 
     * @param point
     * @param bounds
     * @return an int with the appropriate bits set if the Point lies on the corresponding bounds lines
     * 
     */
    public static func check(point:CGPoint, bounds:CGRect)->Int
    {
        var value:Int = 0;
        if (point.x == bounds.minX)
        {
            value |= LEFT;
        }
        if (point.x == bounds.maxX)
        {
            value |= RIGHT;
        }
        if (point.y == bounds.maxY)
        {
            value |= TOP;
        }
        if (point.y == bounds.minY)
        {
            value |= BOTTOM;
        }
        return value;
    }
    
    public init()
    {
        assert(false, "ILLEGAL TO CREATE ONE!")
    }

}
