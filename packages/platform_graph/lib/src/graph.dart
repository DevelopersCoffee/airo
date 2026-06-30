abstract class Node {
  String get id;
}

abstract class Edge {
  String get sourceId;
  String get targetId;
}

class Graph {
  Graph(this.nodes, this.edges);
  final List<Node> nodes;
  final List<Edge> edges;
}

class DirectedGraph extends Graph {
  DirectedGraph(super.nodes, super.edges);
}

class GraphBuilder {
  final List<Node> _nodes = [];
  final List<Edge> _edges = [];

  void addNode(Node node) => _nodes.add(node);
  void addEdge(Edge edge) => _edges.add(edge);

  DirectedGraph build() => DirectedGraph(_nodes, _edges);
}

// GraphOptimizer modifies topological structure
abstract class GraphOptimizer {
  DirectedGraph optimize(DirectedGraph graph);
}
